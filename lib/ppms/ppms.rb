require 'net/http'
require 'uri'
require 'json'
require 'logger'
require 'csv'
require 'cgi'
require 'ostruct'
require 'date'

module PPMS

  class PPMS_Error < StandardError
  end

  class PPMS
    include ::I18n
    
    @@serviceID = 7
    @@affiliation2id = {'CRUK' => 1,
                        'Charity' => 2,
                        'RC / UKGov' => 5,
                        'EC / ERC' => 6,
                        'WT' => 7,
                        'Commercial' => 8,
                        'Core' => 9,
                        'F.I.R.' => 8}

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
      @pmuapi = URI("https://#{@host}/pumapi/")
      @api2 = URI("https://#{@host}/API2/")
      @prices = nil
    end

    # Send a request to the PMUAPI. This was the original behaviour.
    def makeRequest(req,tag,verbose)
      return makeEitherRequest(@pmuapi,req,tag,verbose)
    end
    
    # Send a request to API2.
    def makeRequest2(req,tag,verbose)
      return makeEitherRequest(@api2,req,tag,verbose)
    end

    def makeEitherRequest(api,req,tag,verbose)
      result = nil
      conn = Net::HTTP.new(api.host,api.port)
      if verbose
        conn.set_debug_output $stderr
      end
      conn.use_ssl=true
      conn.start
      result = conn.request(req)
      conn.finish
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
      result.body = result.body.gsub("\t","") # get rid of evil tab characters
      return result
    end

    def isConnected(verbose=false)
      req = Net::HTTP::Post.new(@pmuapi)
      req.set_form_data("apikey" => @key, "action" => "getsystems", "format" => "json")
      result = makeRequest(req,__method__,verbose)
      return false if result.nil?
      return result.code == "200"
    end

    def getUser(id,verbose=false)
      req = Net::HTTP::Post.new(@pmuapi)
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
      req = Net::HTTP::Post.new(@pmuapi)
      req.set_form_data("apikey" => @key, "action" => "getusers")
      result = makeRequest(req,__method__,verbose)
      return result if result.nil?
      begin
        data = result.body.each_line.map{|x| CGI.unescapeHTML(x.strip)}
      rescue
        $ppmslog.error("Failed listUsers: result = '#{result.body}'") if verbose
        data = nil
      end
      return data
    end

    def getSystems(verbose: false)
      req = Net::HTTP::Post.new(@pmuapi)
      req.set_form_data("apikey" => @key, "action" => "getsystems")
      result = makeRequest(req,__method__,verbose)
      return result if result.nil?
      data = csv2dict(result.body,"System id")
      return data
    end

    def getSystemUsers(system,verbose: false)
      req = Net::HTTP::Post.new(@pmuapi)
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
      req = Net::HTTP::Post.new(@pmuapi)
      req.set_form_data("apikey" => @key, "action" => "getservices", "coreid" => core)
      result = makeRequest(req,__method__,verbose)
      return result if result.nil?
      data = csv2dict(result.body,"Name")
      data = data.select{|k,v| v["Group"] != "Admin" and v["Active"] == "True"}
      return data
    end

    def getServiceID(core: 7,name: "Hours",verbose: false)
      data = getServices(core: core,verbose: verbose)
      return data[name]["Service id"]
    end

    def getProjectsRaw(verbose=false)
      req = Net::HTTP::Post.new(@pmuapi)
      req.set_form_data("apikey" => @key, "action" => "getprojects", "format" => "json", "ExpirationDate" => "true")
      result = makeRequest(req,__method__,verbose)
      return result
    end

    def getProjects(verbose=false)
      req = Net::HTTP::Post.new(@pmuapi)
      req.set_form_data("apikey" => @key, "action" => "getprojects", "format" => "json", "ExpirationDate" => "true")
      result = makeRequest(req,__method__,verbose)
      return result if result.nil?
      begin
        data = JSON.parse(result.body)
      rescue JSON::ParserError
        $ppmslog.error("Failed to retrieve projects list")
        puts "GET PROJECTS"
        puts result.body
        puts "END PROJECTS"
        data = nil
      end
      return data
    end

    def getAccountsRaw(core: 7, verbose: false)
      req = Net::HTTP::Post.new(@api2)
      req.set_form_data("apikey" => @key, "action" => "GetPPMSAccounts", "format" => "json", "coreId" => core)
      result = makeRequest2(req,__method__,verbose)
      return result
    end

    def getAccounts(core: 7, verbose: false)
      req = Net::HTTP::Post.new(@api2)
      req.set_form_data("apikey" => @key, "action" => "GetPPMSAccounts", "format" => "json", "coreId" => core)
      result = makeRequest2(req,__method__,verbose)
      return result if result.nil?
      begin
        data = JSON.parse(result.body)
      rescue JSON::ParserError
        $ppmslog.error("Failed to retrieve accounts list")
        puts "GET ACCOUNTS"
        puts result.body
        puts "END ACCOUNTS"
        data = nil
      end
      return data
    end

    def getGroups(verbose=false)
      req = Net::HTTP::Post.new(@pmuapi)
      req.set_form_data("apikey" => @key, "action" => "getgroups")
      result = makeRequest(req,__method__,verbose)
      return result if result.nil?
      begin
        untrimmed_data = result.body.split("\n")
        data = untrimmed_data.map{|x| x.strip}
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
      req = Net::HTTP::Post.new(@pmuapi)
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

    def issue2User(iss,verbose=false)
      email = iss.researcher
      user = nil
      if !email.nil?
        $ppmslog.info("Researcher email: #{email}") if verbose
        erm = EmailRavenMap.find_by(email: email)
        if erm.nil?
          $ppmslog.info("Researcher email #{email} not found in EmailRavenMap")
        else
          user = getUser(erm.raven)
          # should be found, but if not it'll just be 'nil' anyway.
          if user.nil?
            $ppmslog.info("Researcher email in ERM but unsuccessful lookup from PPMS")
          end
        end
      else
        $ppmslog.info("No email associated with issue, trying project")
      end
      if user.nil?
        proj = iss.project
        group = nil
        while group.nil? && !proj.nil?
          $ppmslog.info("Trying project #{proj.name}...")
          group = getGroup(proj,verbose=true)
          if group.nil?
            proj = proj.parent
          else
            $ppmslog.info("Found group for #{proj.name}...")
            break
          end
        end
        if !group.nil?
          email = group['heademail']
          erm = EmailRavenMap.find_by(email: email)
          if erm.nil?
            $ppmslog.info("Group email not in ERM: #{email}")
          else
            $ppmslog.info("Group email: #{email}  Raven: #{erm.raven}")
            user = erm.raven
          end
        end
      end
      return user
    end

    def getOrders(verbose=false)
      req = Net::HTTP::Post.new(@pmuapi)
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
      req = Net::HTTP::Post.new(@pmuapi)
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

    def submitOrder(service,login,quant,bcode,cdate,comments,verbose=true)
      ddate = cdate.to_s
      req = Net::HTTP::Post.new(@pmuapi)
      req.set_form_data("apikey" => @key,
                        "action" => "createorder",
                        "serviceid" => service,
                        "login" => login,
                        "quantity" => quant,
                        "bcode" => bcode,
                        "accepted" => true,
                        "completed" => true,
                        "completeddate" => ddate,
                        "comments" => comments)
      result = makeRequest(req,__method__,verbose)
      ok = /^\d+$/ =~ result.body
      if ok.nil?
          $ppmslog.error("PPMS order creation failed: #{result.body}")
          $ppmslog.error("service = #{service}")
          $ppmslog.error("login = #{login}")
          $ppmslog.error("quantity = #{quant}")
          $ppmslog.error("bcode = #{bcode}")
          $ppmslog.error("cdate = #{cdate}")
          $ppmslog.error("comments = #{comments}")
        raise PPMS_Error.new(result.body)
      end
      return result.body.to_i
    end

    def loadPricesCSV(verbose=false)
      req = Net::HTTP::Post.new(@pmuapi)
      req.set_form_data("apikey" => @key,
                        "action" => "getpriceslist",
                        "format" => "csv")
      result = makeRequest(req,__method__,verbose)
      rows = ::CSV.parse(result.body)
      hdrRow = rows[0].map{|x| x.strip}
      prioCol = hdrRow.find_index("priority")
      serviceCol = hdrRow.find_index("service")
      affCol = hdrRow.find_index("affiliationid")
      projCol = hdrRow.find_index("projectid")
      priceCol = hdrRow.find_index("Price")
      @prices = Array.new()
      rows[1..rows.length-1].each do |row|
        @prices << OpenStruct.new(:priority => row[prioCol].to_i,
                                  :service => (row[serviceCol].to_i + @@serviceID * 10**4).to_s,
                                  :affiliation => row[affCol].to_i,
                                  :project => row[projCol].to_i,
                                  :price => row[priceCol].to_f)
      end
      return @prices
    end

    def loadPrices(verbose=false)
      req = Net::HTTP::Post.new(@pmuapi)
      req.set_form_data("apikey" => @key,
                        "action" => "getpriceslist",
                        "format" => "json")
      result = makeRequest(req,__method__,verbose)
      return result if result.nil?
      prices = Array.new()
      begin
        data = JSON.parse(result.body)
        today = Date.today
        if !data.nil?
          data.each do |row|
            rowDat = OpenStruct.new(
                           :priority => row["priority"],
                           :service => (row["service"].to_i + @@serviceID * 10**4).to_s,
                           :affiliation => row["affiliationid"],
                           :project => row["projectid"],
                           :price => row["price"],
                           :startDate => Date.parse(row["minDate"]),
                           :endDate => Date.parse(row["maxDate"]))
            if rowDat.startDate <= today && rowDat.endDate >= today
              prices << rowDat
            end
          end
        end
      rescue JSON::ParserError
        $ppmslog.error("Failed getUser: userid not found '#{id}'") if verbose
        data = nil
      end
      @prices = prices
      return prices
    end

    def dumpPrices(destination: $stderr,priceList: nil)
      if @prices.nil?
        loadPrices()
      end
      if priceList.nil?
        priceList = @prices
      end
      priceList.each do |p|
        destination.printf("prio: %1d\tserv: %3d\taff:  %d\tproj: %3d\tprice: %6.2f\n",
                           p.priority,p.service,p.affiliation,p.project,p.price)
      end
      return nil
    end

    def getRate(affiliation: nil, service: nil)
      if @prices.nil?
        loadPrices()
      end
      if service.nil?
        raise PPMS_Error.new(sprintf("getRate: no service provided (affiliation==%s)",affiliation))
      end
      if affiliation.nil?
        raise PPMS_Error.new(sprintf("getRate: no affiliation provided (service==%s)",service))
      end
      affId = @@affiliation2id[affiliation]
      if affId.nil?
        raise PPMS_Error.new(sprintf("getRate: unknown affiliation provided (affiliation==%s, service==%s)",affiliation,service))
      end

      # note that service must match; there's no "any" service.
      priceList = @prices.select {|p| p.service == service}

      # look for a matching affiliation
      aff_priceList = priceList.select {|p| p.affiliation == affId}
      if aff_priceList.length > 0
        priceList = aff_priceList
      end
      if priceList.length > 1
        topPrio = priceList.map {|p| p.priority}.min
        priceList = priceList.select {|p| p.priority == topPrio}
      end
      if priceList.length > 1
        printf(" ******* getRate: priceList length = %d  aff: %s  serv: %s\n",priceList.length,affiliation, service)
      end
      # by now priceList should have exactly one entry.  If not, it's the caller's problem.
      return priceList
    end

    def getPrice(units,affiliation: nil,costCode: nil, service: nil)
      if @prices.nil?
        loadPrices()
      end
      rate = getRate(affiliation: affiliation, service: service)
      if rate.length > 1
        raise PPMS_Error.new(sprintf("non-unique price for aff=%s,cc=%s,serv=%s",affiliation,costCode,service))
      end
      if rate.length == 0
        raise PPMS_Error.new(sprintf("no matching price rule for aff=%s,cc=%s,serv=%s",affiliation,costCode,service))
      end
      rule = rate[0]
      cost = units.to_f * rule.price
      return cost
    end

    def getBcodes(verbose=false)
      req = Net::HTTP::Post.new(@pmuapi)
      req.set_form_data("apikey" => @key,
                        "action" => "getbcodes")
      result = makeRequest(req,__method__,verbose)
      data = csv2dict(result.body,"Bcode",headerRow: 0)
      return data
    end

  end
end
