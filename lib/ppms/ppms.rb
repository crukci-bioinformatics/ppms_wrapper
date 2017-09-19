require 'net/http'
require 'json'
require 'logger'
require 'csv'
require 'cgi'

module PPMS

  class PPMS_Error < StandardError
  end

  class PPMS
    include ::I18n
    
    @@affiliation2id = {'Internal' => 1,
                        'Charity' => 2,
                        'RC / UKGov' => 5,
                        'EC / ERC' => 6,
                        'WT' => 7,
                        'Commercial' => 8,
                        'Core' => 9}

    def csv2dict(data,indexKey,headerRow: 0)
      rows = ::CSV.parse(data)
      hdrRow = rows[headerRow].map{|x| x.strip}
      index = hdrRow.find_index(indexKey)
      inames = hdrRow
      data = {}
      rows.each_index do |i|
        next if i <= headerRow
        rdata = {}
        row = rows[i]
        row = row.map{|x| x.nil? ? nil : x.strip}
        next if row.blank?
        row.each_index do |col|
          rdata[inames[col]] = row[col]
        end
        data[row[index]] = rdata
      end
      return data
    end

    def initialize(host: nil, key: nil)
      @host = host.nil? ? Setting.plugin_ppms['api_url'] : host
      @key = key.nil? ? Setting.plugin_ppms['api_key'] : key
      @uri = URI("https://#{@host}/pumapi/")
      @prices = nil
    end

    def makeRequest(req,tag,verbose)
      result = nil
      Net::HTTP.start(@uri.host,@uri.port, :use_ssl => true) do |conn|
        result = conn.request(req)
      end
      if result.nil? or !result.is_a?(Net::HTTPResponse)
        $ppmslog.error("Failed #{tag}: response not a 'Net::HTTPResponse' object (#{result.class})") if verbose
        return nil
      elsif result.code != "200"
        $ppmslog.error("Failed #{tag}: response code == '#{result.code}'") if verbose
        return nil
      elsif result.body.strip == "error: request not authorized"
        $ppmslog.error("Failed #{tag}: bad API key '#{@key}'") if verbose
        return nil
      end
      return result
    end

    def isConnected(verbose=false)
      req = Net::HTTP::Post.new(@uri)
      req.set_form_data("apikey" => @key, "action" => "getsystems", "format" => "json")
      result = makeRequest(req,__method__,verbose)
      return false if result.nil?
      return result.code == "200"
    end

    def getUser(id,verbose=false)
      req = Net::HTTP::Post.new(@uri)
      req.set_form_data("apikey" => @key, "action" => "getuser", "login" => id, "format" => "json")
      result = makeRequest(req,__method__,verbose)
      return result if result.nil?
      begin
        data = JSON.parse(result.body)
        if !data.nil?
          data.each do |k,v|
            data[k] = CGI.unescapeHTML(v) if v.is_a?(String)
          end
        end
      rescue JSON::ParserError
        $ppmslog.error("Failed getUser: userid not found '#{id}'") if verbose
        data = nil
      end
      return data
    end

    def listUsers(verbose=false)
      req = Net::HTTP::Post.new(@uri)
      req.set_form_data("apikey" => @key, "action" => "getusers")
      result = makeRequest(req,__method__,verbose)
      return result if result.nil?
      begin
        data = result.body.split.map{|x| CGI.unescapeHTML(x)}
      rescue
        $ppmslog.error("Failed listUsers: result = '#{result.body}'") if verbose
        data = nil
      end
      return data
    end

    def getSystems(verbose: false)
      req = Net::HTTP::Post.new(@uri)
      req.set_form_data("apikey" => @key, "action" => "getsystems")
      result = makeRequest(req,__method__,verbose)
      return result if result.nil?
      data = csv2dict(result.body,"System id")
      return data
    end

    def getSystemUsers(system,verbose: false)
      req = Net::HTTP::Post.new(@uri)
      req.set_form_data("apikey" => @key, "action" => "getsysrights", "id" => system)
      result = makeRequest(req,__method__,verbose)
      return result if result.nil?
      data = result.body.split.map{|x| x.split(":")[1]}
      return data
    end
      
    def getServices(core: 7,verbose: false)
      if core.nil?
        $ppmslog.error("#{__method__}: 'core' parameter must not be nil.") if verbose
        return nil
      end
      req = Net::HTTP::Post.new(@uri)
      req.set_form_data("apikey" => @key, "action" => "getservices", "coreid" => core)
      result = makeRequest(req,__method__,verbose)
      return result if result.nil?
      data = csv2dict(result.body,"Name")
      data = data.select{|k,v| v["Group"] != "Admin"}
      return data
    end

    def getServiceID(core: 7,name: "Hours",verbose: false)
      data = getServices(core: core,verbose: verbose)
      return data[name]["Service id"]
    end

    def getProjects(verbose=false)
      req = Net::HTTP::Post.new(@uri)
      req.set_form_data("apikey" => @key, "action" => "getprojects", "format" => "json")
      result = makeRequest(req,__method__,verbose)
      return result if result.nil?
      data = JSON.parse(result.body)
      return data
    end

    def getGroups(verbose=false)
      req = Net::HTTP::Post.new(@uri)
      req.set_form_data("apikey" => @key, "action" => "getgroups")
      result = makeRequest(req,__method__,verbose)
      return result if result.nil?
      begin
        data = result.body.split
      rescue
        $ppmslog.error("Failed #{__method__}: result = '#{result.body}'") if verbose
        data = nil
      end
      return data
    end

    def getGroup(gp,verbose=false)
      cf = CustomField.find_by(name: 'PPMS Group ID')
      gpname = nil
      if cf
        cfid = cf.id
        ppms_ids = gp.custom_values.select{|x| x.custom_field_id == cfid}
        if ppms_ids.length > 0
          gpname = ppms_ids[0].value
        end
      end
      gpname = I18n.transliterate(gp.name.strip) if gpname.blank?
      req = Net::HTTP::Post.new(@uri)
      req.set_form_data("apikey" => @key, "action" => "getgroup","unitlogin" => gpname)
      result = makeRequest(req,__method__,verbose)
      return result if result.nil?
      begin
        tdata = csv2dict(result.body,"unitlogin")
        data = tdata[tdata.keys()[0]]
      rescue
        $ppmslog.error("Failed #{__method__}: result = '#{result.body}'") if verbose
        data = nil
      end
      return data
    end

    def getOrders(verbose=false)
      req = Net::HTTP::Post.new(@uri)
      req.set_form_data("apikey" => @key, "action" => "getorders")
      result = makeRequest(req,__method__,verbose)
      return result if result.nil?
      begin
        data = csv2dict(result.body,"Order ref.",headerRow: 1)
      rescue
        $ppmslog.error("Failed #{__method__}: result = '#{result.body}'") if verbose
        data = nil
      end
      return data
    end

    def getOrder(id,verbose=false)
      req = Net::HTTP::Post.new(@uri)
      req.set_form_data("apikey" => @key, "action" => "getorderlines", "orderref" => id)
      result = makeRequest(req,__method__,verbose)
      return result if result.nil?
      begin
        data = csv2dict(result.body,"Order ID",headerRow: 0)
      rescue
        $ppmslog.error("Failed #{__method__}: result = '#{result.body}'") if verbose
        data = nil
      end
      return data
    end

    def submitOrder(service,login,quant,project,cdate,verbose=true)
      ddate = cdate.to_s
      req = Net::HTTP::Post.new(@uri)
      req.set_form_data("apikey" => @key,
                        "action" => "createorder",
                        "serviceid" => service,
                        "login" => login,
                        "quantity" => quant,
                        "projectid" => project,
                        "accepted" => true,
                        "completed" => true,
                        "completeddate" => ddate)
      result = makeRequest(req,__method__,verbose)
      ok = /^\d+$/ =~ result.body
      if ok.nil?
        raise PPMS_Error.new(result.body)
      end
      return result.body.to_i
    end

    def loadPrices(verbose=false)
      req = Net::HTTP::Post.new(@uri)
      req.set_form_data("apikey" => @key,
                        "action" => "getpriceslist",
                        "format" => "csv")
      result = makeRequest(req,__method__,verbose)
      rows = ::CSV.parse(result.body)
      hdrRow = rows[0].map{|x| x.strip}
      affCol = hdrRow.find_index("affiliationid")
      projCol = hdrRow.find_index("projectid")
      priceCol = hdrRow.find_index("Price")
      @prices = Hash.new(default=0)
      rows[1..rows.length-1].each do |row|
        affId = row[affCol].to_i
        projId = row[projCol].to_i
        price = row[priceCol].to_f
        if !@prices.include?(affId)
          @prices[affId] = Hash.new(default=0)
        end
        @prices[affId][projId] = price
      end
      return @prices
    end

    def getPrice(units,affiliation: nil,costCode: nil)
      if @prices.nil?
        loadPrices()
      end
      affId = @@affiliation2id[affiliation]
      affId = (affId.nil? || !@prices.include?(affId)) ? 0 : affId
      costId = costCode.nil? ? 0 : costCode
      price = 0
      if affId == 0
        if @prices[affId].include? costId
          price = @prices[affId][costId]
        end
      else
        if @prices[affId].include? costId
          price = @prices[affId][costId]
        else
          price = @prices[affId][0]
        end
      end
      return units.to_f * price
    end

    def getBcodes(verbose=false)
      req = Net::HTTP::Post.new(@uri)
      req.set_form_data("apikey" => @key,
                        "action" => "getbcodes")
      result = makeRequest(req,__method__,verbose)
      data = csv2dict(result.body,"Bcode",headerRow: 0)
      return data
    end

  end
end
