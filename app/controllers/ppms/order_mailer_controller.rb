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
      
        @time_orders_by_issue = mailer.assembleTimeOrderEntries()
        flat_time_orders = @time_orders_by_issue.values.flatten 

        @issues = Hash.new
    
        flat_time_orders.each do |time_order|
            @issues[time_order.issue.id] = time_order.issue
        end

        projects = @issues.values.map{ |issue| issue.project }.uniq
        
        @ppms_groups_by_project_id = mailer.getPPMSGroupsForProjects(projects)

        @ppms_orders = Hash.new
        
        @time_orders_by_issue.each do |issue_id, time_entry_orders|
            issue = @issues[issue_id]
            ppms_group = @ppms_groups_by_project_id[issue.project.id]
            
            order_ids = time_entry_orders.map { |time_order| time_order.order_id }.uniq
                
            order_ids.each do |order_id|
                @ppms_orders[order_id] = mailer.getPPMSOrder(order_id, ppms_group)
            end
        end
    end
  
    def hours_minutes(time)
        hm = (time * 60).round.divmod(60)
        sprintf("%d:%02d", hm[0], hm[1])
    end
end
