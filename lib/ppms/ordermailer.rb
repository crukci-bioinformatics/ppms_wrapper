require 'ostruct'

require_relative 'ppms'
require_relative 'utils'

module PPMS
    class OrderMailer
    
        include Utilities
      
        def initialize
            @ppms = PPMS.new
            @root_project_ids = getRootProjects(Setting.plugin_ppms['mailing_root'])
        end
        
        ##
        # Finds time_entry_order objects that have not been mailed already and whose
        # project is under the roots defined by the "mailing_root" setting.
        #
        # @return [Hash] A hash of issue number to an array of time_entry_order objects for
        # that issue.
        #
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

        ##
        # Search PPMS to get the PPMS group that is relevant to the given Redmine
        # projects.
        #
        # @param [Array of project] projects The projects to get the groups for.
        #
        # @return [Hash] A hash of Redmine project id to the Hash from PPMS of group information.
        #     
        def getPPMSGroupsForProjects(projects)
            ppms_groups_by_project_id = Hash.new
            
            projects.each do |project|
                project_id = project.id
                if ppms_groups_by_project_id[project_id].nil?
                    begin
                        group = ppms_group_for_project(project)
                        if not group.nil?
                            ppms_groups_by_project_id[project_id] = group
                            $ppmslog.debug("PPMS project #{project_id} is group #{group}")
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
        
        ##
        # Load an order from PPMS, adding the cost of the order.
        #
        # @param [int] The PPMS order id.
        # @param [Hash] The PPMS Group information for this order.
        #
        # @return [Hash] The hash from PPMS containing the order information.
        #
        def getPPMSOrder(ppms_order_id, ppms_group)
            
            ppms_order = nil
            
            begin
                ppms_order = @ppms.getOrder(ppms_order_id)[ppms_order_id.to_s]
          
                # Note that the service id we're looking for is the core facility id * 10000 + the service id.
                # This is handled by PPMS::get_facility_service_id
          
                ppms_order['Cost'] = "Unavailable"
                begin
                    service_id = @ppms.get_facility_service_id(ppms_order['ServiceID']).to_s
                    ppms_order['Rate'] = @ppms.getRate(affiliation: ppms_group['affiliation'], service: service_id)[0].price
                    ppms_order['Cost'] = ppms_order['Rate'] * ppms_order['Quantity'].to_f
                rescue PPMS_Error => failure
                    $ppmslog.error(failure.message)
                end
              
                $ppmslog.debug("PPMS order #{ppms_order_id} is #{ppms_order} and costs #{ppms_order['Cost']}")
            rescue OpenSSL::SSL::SSLError => ssl_error
                $ppmslog.warn("Error fetching order #{ppms_order_id}: #{ssl_error}")
            rescue Net::OpenTimeout => timeout
                $ppmslog.warn("Time out fetching order #{ppms_order_id}: #{timeout}")
            end
            
            return ppms_order
        end
    
        ##
        # Fetch unnotified time order entries and assemble them by group.
        #
        # @return [Hash] A complicated hash keyed by PPMS group login (effectively
        # id) to an OpenStruct containing:
        # "group" - a hash returned from PPMS for the group information;
        # "issues" - a hash of issue id to Redmine issue object;
        # "time_entries" - a hash of issue id to array of time order entries (as returned from assembleTimeOrderEntries);
        # "orders" - a hash of PPMS order id to PPMS order hash.
        # "orders_by_issue" - a hash of Redmine issue id to an array of orders for that issue.
        #
        def assembleOrdersToGroups()
            
            time_orders_by_issue = assembleTimeOrderEntries()
            flat_time_orders = time_orders_by_issue.values.flatten 
    
            issues = Hash.new
        
            flat_time_orders.each do |time_order|
                issues[time_order.issue.id] = time_order.issue
            end
    
            projects = issues.values.map{ |issue| issue.project }.uniq
            ppms_groups_by_project_id = getPPMSGroupsForProjects(projects)
            
            issues_by_group = Hash.new
            
            time_orders_by_issue.each do |issue_id, time_order_entries|
                issue = issues[issue_id]
                ppms_group = ppms_groups_by_project_id[issue.project.id]
                group_id = ppms_group["unitlogin"]
                
                group_struct = issues_by_group[group_id]
                if group_struct.nil?
                    group_struct = OpenStruct.new(:group => ppms_group, :issues => Hash.new, :time_entries => Hash.new, :orders => Hash.new, :orders_by_issue => Hash.new)
                    issues_by_group[group_id] = group_struct
                end
                
                group_struct.issues[issue_id] = issue
                group_struct.time_entries[issue_id] = time_order_entries
                    
                order_ids = time_order_entries.map { |time_order| time_order.order_id }.uniq
                    
                order_ids.each do |order_id|
                    if group_struct.orders[order_id].nil?
                        ppms_order = getPPMSOrder(order_id, ppms_group)
                        group_struct.orders[order_id] = ppms_order
                    end
                end
                
                flat_time_orders.each do |time_order|
                    issue_id = time_order.issue.id
                    order_id = time_order.order_id
                    if group_struct.orders_by_issue[issue_id].nil?
                        group_struct.orders_by_issue[issue_id] = Hash.new
                    end
                    group_struct.orders_by_issue[issue_id][order_id] = group_struct.orders[order_id]
                end
            end
            
            return issues_by_group
        end
        
        def assembleMails()
        # https://guides.rubyonrails.org/active_record_querying.html
        #projects = collectProjects(Setting.plugin_ppms['project_root'])
        #time_orders = TimeEntryOrder.find_by(mailed_at: nil)
        #TimeEntryOrder.joins(:time_entry).joins(:project).where(:project in projects)
        end

        private

        ##
        # Helper for finding a PPMS group for a project. Takes the project's
        # "PPMS Group ID" value or, failing that, the project name and looks for
        # a group in PPMS that is called the same. If not found, it repeats the
        # test for the project's parent project until either there is no parent
        # project or the parent is one of the mailing roots.
        #
        # @param [project] The PPMS project.
        #
        # @return [Hash} The hash from PPMS for the group associated with this project.
        # 
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
