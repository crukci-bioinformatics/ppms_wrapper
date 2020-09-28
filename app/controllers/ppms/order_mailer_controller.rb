require 'ppms/utils'
require 'ppms/ordermailer'

class Ppms::OrderMailerController < ApplicationController

    include PPMS::Utilities
  
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
  
    def hours_minutes(time)
        hm = (time * 60).round.divmod(60)
        sprintf("%d:%02d", hm[0], hm[1])
    end
end
