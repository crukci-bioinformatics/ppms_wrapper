require 'net/http'
require 'json'
require 'logger'
require 'csv'

module PPMS
  class PPMS

    def csv2dict(data,indexKey)
      rows = ::CSV.parse(data)
      index = rows[0].find_index(indexKey)
      inames = rows[0]
      data = {}
      rows.each_index do |i|
        next if i == 0
        rdata = {}
        row = rows[i]
        row.each_index do |col|
          rdata[inames[col]] = row[col]
        end
        data[row[index]] = rdata
      end
      return data
    end

    def initialize(host,apikey)
      @host = host
      @key = apikey
      @uri = URI("https://#{@host}/pumapi/")
      $log = Logger.new(STDERR)
      $log.level = Logger::DEBUG
    end

    def makeRequest(req,tag,verbose)
      result = nil
      Net::HTTP.start(@uri.host,@uri.port, :use_ssl => true) do |conn|
        result = conn.request(req)
      end
      if result.nil? or !result.is_a?(Net::HTTPResponse)
        $log.error("Failed #{tag}: response not a 'Net::HTTPResponse' object (#{result.class})") if verbose
        return nil
      elsif result.code != "200"
        $log.error("Failed #{tag}: response code == '#{result.code}'") if verbose
        return nil
      elsif result.body.strip == "error: request not authorized"
        $log.error("Failed #{tag}: bad API key '#{@key}'") if verbose
        return nil
      end
      return result
    end

    def isConnected(verbose=false)
      result = false
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
      rescue JSON::ParserError
        $log.error("Failed getUser: userid not found '#{id}'") if verbose
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
        data = result.body.split
      rescue
        $log.error("Failed listUsers: result = '#{result.body}'") if verbose
        data = nil
      end
      return data
    end

    def getServices(core=7,verbose=false)
      if core.nil?
        $log.error("#{__method__}: 'core' parameter must not be nil.") if verbose
        return nil
      end
      req = Net::HTTP::Post.new(@uri)
      req.set_form_data("apikey" => @key, "action" => "getservices", "coreid" => core)
      result = makeRequest(req,__method__,verbose)
      return result if result.nil?
      data = csv2dict(result.body,"Name")
      return data
    end

    def getServiceID(core=7,name="Hours",verbose=false)
      data = getServices(verbose=verbose)
      return data[name]["Service id"]
    end

    def getProjects(verbose=false)
      req = Net::HTTP::Post.new(@uri)
      req.set_form_data("apikey" => @key, "action" => "getprojects")
      result = makeRequest(req,__method__,verbose)
      return result if result.nil?
      return result.body
    end

    def getGroups(verbose=false)
      req = Net::HTTP::Post.new(@uri)
      req.set_form_data("apikey" => @key, "action" => "getgroups")
      result = makeRequest(req,__method__,verbose)
      return result if result.nil?
      return result.body
    end

    def getGroups(verbose=false)
      req = Net::HTTP::Post.new(@uri)
      req.set_form_data("apikey" => @key, "action" => "getgroups")
      result = makeRequest(req,__method__,verbose)
      return result if result.nil?
      return result.body
    end

    def getOrder(id,verbose=false)
      req = Net::HTTP::Post.new(@uri)
      req.set_form_data("apikey" => @key, "action" => "getorders")
      result = makeRequest(req,__method__,verbose)
      return result if result.nil?
      return result.body
    end
  end
end
