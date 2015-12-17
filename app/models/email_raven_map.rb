require 'uri'
require 'cgi'

require 'ppms/ppms'

class EmailRavenMap < ActiveRecord::Base
  unloadable

  def self.refresh(ppms)
    include URI::Escape
    ravens = ppms.listUsers
    ravens.each do |raven|
      raven = CGI.unescapeHTML(raven)
      next if EmailRavenMap.find_by(raven: raven)
      begin
        data = ppms.getUser(URI.escape(raven))
        email = CGI.unescapeHTML(data['email'])
        login = CGI.unescapeHTML(data['login'])
        EmailRavenMap.create(email: email, raven: login)
        $ppmslog.info("Adding #{email} <--> #{login}")
      rescue NoMethodError
        if data.nil?
          $ppmslog.error("No data for raven='#{raven}'") if data.nil?
        else
          $ppmslog.error("Nil email for raven='#{raven}' (#{data['login']})") if data['email'].nil?
          $ppmslog.error("Nil login for raven='#{raven}' (#{data['email']})") if data['login'].nil?
        end
      end
    end
  end

end
