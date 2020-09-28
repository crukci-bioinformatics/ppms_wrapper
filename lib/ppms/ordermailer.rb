require_relative 'ppms'
require_relative 'utils'

module PPMS
    class OrderMailer
    
        include Utilities
      
        def initialize
            @ppms = PPMS.new
            @root_project_ids = getRootProjects(Setting.plugin_ppms['mailing_root'])
        end
        
        def assembleTimeOrderEntries()
            # Find projects that have entries we want to mail. They'll be the ones
            # under those named in the "mailing_root" setting.
            
            mailing_project_ids = collectProjects(Setting.plugin_ppms['mailing_root'])
            
            # Find time entry order that have not been mailed whose project is in
            # the projects under the mailing roots.
            time_orders = TimeEntryOrder.joins(time_entry: :project).where(mailed_at: nil, projects: {id: mailing_project_ids })
            $ppmslog.info("Time entry orders to mail: #{time_orders.size}")
        
            orders_by_issue = Hash.new
            
            time_orders.each do |time_order|
                issue = time_order.time_entry.issue
              
                current = orders_by_issue[issue.id]
                if current.nil?
                    current = Array.new
                    orders_by_issue[issue.id] = current
                end
                current << time_order
            end
            
            return orders_by_issue
        end
        
        def getPPMSGroupsForProjects(projects)
            ppms_groups_by_project_id = Hash.new
            
            projects.each do |project|
                project_id = project.id
                if ppms_groups_by_project_id[project_id].nil?
                    begin
                        group = ppms_group_for_project(project)
                        if not group.nil?
                            ppms_groups_by_project_id[project_id] = group
                            $ppmslog.info("PPMS project #{project_id} is group #{group}")
                        end
                    rescue OpenSSL::SSL::SSLError => ssl_error
                        $ppmslog.warn("Error fetching group for project #{project_id}: #{ssl_error}")
                    rescue Net::OpenTimeout => timeout
                        $ppmslog.warn("Time out fetching group for project #{project_id}: #{timeout}")
                    end
                end
            end
            
            return ppms_groups_by_project_id
        end
        
        def getPPMSOrder(ppms_order_id, ppms_group)
            
            ppms_order = nil
            
            begin
                ppms_order = @ppms.getOrder(ppms_order_id)[ppms_order_id.to_s]
          
                # Note that the service id we're looking for is the core facility id * 10000 + the service id.
                # This is handled by PPMS::get_facility_service_id
          
                ppms_order['Cost'] = "Unavailable"
                begin
                    service_id = @ppms.get_facility_service_id(ppms_order['ServiceID']).to_s
                    ppms_order['Cost'] = @ppms.getPrice(ppms_order['Quantity'].to_f, affiliation: ppms_group['affiliation'], service: service_id)
                rescue PPMS::PPMS_Error => failure
                    $ppmslog.error(failure.message)
                end
              
                $ppmslog.info("PPMS order #{ppms_order_id} is #{ppms_order} and costs #{ppms_order['Cost']}")
            rescue OpenSSL::SSL::SSLError => ssl_error
                $ppmslog.warn("Error fetching order #{ppms_order_id}: #{ssl_error}")
            rescue Net::OpenTimeout => timeout
                $ppmslog.warn("Time out fetching order #{ppms_order_id}: #{timeout}")
            end
            
            return ppms_order
        end
    
        def assembleMails()
        # https://guides.rubyonrails.org/active_record_querying.html
        #projects = collectProjects(Setting.plugin_ppms['project_root'])
        #time_orders = TimeEntryOrder.find_by(mailed_at: nil)
        #TimeEntryOrder.joins(:time_entry).joins(:project).where(:project in projects)
        end

        private

        def ppms_group_for_project(project)
    
            group = @ppms.getGroup(project)
        
            if group.nil? and !project.parent_id.nil? and !@root_project_ids.include?(project.parent_id)
                parent = Project.find(project.parent_id)
                group = ppms_group_for_project(parent)
            end
        
            return group
        end
    end
end
