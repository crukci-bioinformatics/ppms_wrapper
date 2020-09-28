require 'ppms/utils'
require 'ppms/ordermailer'

class Ppms::OrderMailerController < ApplicationController

    include PPMS::Utilities
  
    unloadable
  
    helper_method :hours_minutes

    def index
        @researcher_field = CustomField.find_by(name: "Researcher Email")
        @experiment_type_field = CustomField.find_by(name: "Experiment Type")
      
        @root_project_ids = getRootProjects(Setting.plugin_ppms['mailing_root'])
        
        mailer = PPMS::OrderMailer.new
      
        @orders_by_issue = mailer.assembleTimeOrderEntries()

        ppms = PPMS::PPMS.new
      
        @issues = Hash.new
        @ppms_orders = Hash.new
        @ppms_groups_by_project_id = Hash.new
    
        @orders_by_issue.each do |issue_id, time_orders|
            time_orders.each do |time_order|
                issue = time_order.time_entry.issue
                @issues[issue.id] = issue
      
                project_id = time_order.project.id
                if @ppms_groups_by_project_id[project_id].nil?
                    begin
                        group = get_ppms_group_for_project(ppms, time_order.project)
                        if not group.nil?
                            @ppms_groups_by_project_id[project_id] = group
                            $ppmslog.info("PPMS project #{project_id} is group #{group}")
                        end
                    rescue OpenSSL::SSL::SSLError => ssl_error
                        $ppmslog.warn("Error fetching group for project #{project_id}: #{ssl_error}")
                    rescue Net::OpenTimeout => timeout
                        $ppmslog.warn("Time out fetching group for project #{project_id}: #{timeout}")
                    end
                end
        
                order_id = time_order.order_id
                if @ppms_orders[order_id].nil?
                    begin
                        ppms_group = @ppms_groups_by_project_id[project_id]
                  
                        ppms_order = ppms.getOrder(order_id)[order_id.to_s]
                        @ppms_orders[order_id] = ppms_order
                  
                        # Note that the service id we're looking for is the core facility id * 10000 + the service id.
                        # This is handled by PPMS::get_facility_service_id
                  
                        ppms_order['Cost'] = "Unavailable"
                        begin
                            service_id = ppms.get_facility_service_id(ppms_order['ServiceID']).to_s
                            ppms_order['Cost'] = ppms.getPrice(ppms_order['Quantity'].to_f, affiliation: ppms_group['affiliation'], service: service_id)
                        rescue PPMS::PPMS_Error => failure
                            $ppmslog.error(failure.message)
                        end
                      
                        $ppmslog.info("PPMS order #{order_id} is #{ppms_order} and costs #{ppms_order['Cost']}")
                    rescue OpenSSL::SSL::SSLError => ssl_error
                        $ppmslog.warn("Error fetching order #{order_id}: #{ssl_error}")
                    rescue Net::OpenTimeout => timeout
                        $ppmslog.warn("Time out fetching order #{order_id}: #{timeout}")
                    end
                end
            end
        end
    end
  
    def hours_minutes(time)
        hm = (time * 60).round.divmod(60)
        sprintf("%d:%02d", hm[0], hm[1])
    end
  
    def get_ppms_group_for_project(ppms, project)
    
        group = ppms.getGroup(project)
    
        if group.nil? and !project.parent_id.nil? and !@root_project_ids.include?(project.parent_id)
            parent = Project.find(project.parent_id)
            group = get_ppms_group_for_project(ppms, parent)
        end
    
        return group
    end
end
