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
      data = ppms.getUser(URI.escape(raven))
      erm = EmailRavenMap.find_by(raven: raven)
      if erm.nil?
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
      else
        if erm.email != data['email']
          erm.email = data['email']
          erm.save
          $ppmslog.info("Updating #{raven} with email '#{erm.email}'")
        end
      end
    end
  end

end
