require 'ppms/ordermailer'

class Ppms::OrderMailerController < ApplicationController

    unloadable

    helper_method :hours_minutes, :ppms_url, :contributors

    def initialize
        super
        @researcher_field = CustomField.find_by(name: "Researcher Email")
        @experiment_type_field = CustomField.find_by(name: "Experiment Type")
    end

    def index
        mailer = PPMS::OrderMailer.new
        @issues_by_group = mailer.assembleOrdersToGroups
        @max_subject_length = 45
    end

    def create
        mailer = PPMS::OrderMailer.new
        mailer.markIrrelevantTimeEntries
        @sent_to = mailer.sendMails
    end

    def hours_minutes(time)
        return PPMS::OrderMailer.hours_minutes(time)
    end

    def ppms_url(order_id)
        base_url = Setting.plugin_ppms['api_url']
        return "https://#{base_url}/vorder/?orderid=#{order_id}"
    end

    def contributors(time_entry_orders)
        return PPMS::OrderMailer.contributors(time_entry_orders)
    end
end
