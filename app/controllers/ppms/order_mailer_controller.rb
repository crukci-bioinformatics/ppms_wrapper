require 'ppms/ordermailer'

class Ppms::OrderMailerController < ApplicationController

    unloadable
  
    helper_method :hours_minutes

    def initialize
        super
        @researcher_field = CustomField.find_by(name: "Researcher Email")
        @experiment_type_field = CustomField.find_by(name: "Experiment Type")
    end
    
    def index
        mailer = PPMS::OrderMailer.new
        @issues_by_group = mailer.assembleOrdersToGroups
    end
    
    def create
        mailer = PPMS::OrderMailer.new
        mailer.markIrrelevantTimeEntries
        @sent_to = mailer.sendMails
    end
  
    def hours_minutes(time)
        return PPMS::OrderMailer.hours_minutes(time)
    end
end
