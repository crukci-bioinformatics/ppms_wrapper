class Ppms::EmailRavenMapsController < ApplicationController

  unloadable

  def index
    @emails = EmailRavenMap.all
    @emails = @emails.sort { |a,b| a.email.downcase <=> b.email.downcase}
  end

end
