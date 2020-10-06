require 'date'
require "mail"
require 'ostruct'

require_relative 'ppms'
require_relative 'utils'

module PPMS
    class OrderMailer

        include Utilities
        include ActionView::Helpers::TextHelper
        
        @@testing_recipient = "richard.bowers@cruk.cam.ac.uk"
        @@production_bcc = [ "richard.bowers@cruk.cam.ac.uk", "matthew.eldridge@cruk.cam.ac.uk", "gordon.brown@cruk.cam.ac.uk" ]

        @@irrelevant_date = DateTime.new(1974, 9, 19, 18, 0, 0, '+1')

        @@smtp_settings = {
            address: Redmine::Configuration['email_delivery']['smtp_settings'][:address],
            port: Redmine::Configuration['email_delivery']['smtp_settings'][:port],
            domain: Redmine::Configuration['email_delivery']['smtp_settings'][:domain],
            authentication: Redmine::Configuration['email_delivery']['smtp_settings'][:authentication],
            tls: Redmine::Configuration['email_delivery']['smtp_settings'][:tls],
            enable_starttls_auto: Redmine::Configuration['email_delivery']['smtp_settings'][:enable_starttls_auto],
            user_name: Redmine::Configuration['email_delivery']['smtp_settings'][:user_name],
            password: Redmine::Configuration['email_delivery']['smtp_settings'][:password]
        }

        def initialize
            @ppms = PPMS.new
            @root_project_ids = getRootProjects(Setting.plugin_ppms['mailing_root'])
        end

        ##
        # Convert a float of fractional hours into hours:minutes.
        #
        # @param [float] Hours as a decimal.
        # @return [string] Hours as h:mm.
        #
        def self.hours_minutes(time)
            hm = (time * 60).round.divmod(60)
            sprintf("%d:%02d", hm[0], hm[1])
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
                            # $ppmslog.debug("PPMS project #{project_id} is group #{group}")
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
                # This is handled by PPMS::getFacilityServiceId

                ppms_order['Cost'] = "Unavailable"
                begin
                    service_id = @ppms.getFacilityServiceId(ppms_order['ServiceID']).to_s
                    ppms_order['Rate'] = @ppms.getRate(affiliation: ppms_group['affiliation'], service: service_id)[0].price
                    ppms_order['Cost'] = ppms_order['Rate'] * ppms_order['Quantity'].to_f
                rescue PPMS_Error => failure
                    $ppmslog.error(failure.message)
                end

                # $ppmslog.debug("PPMS order #{ppms_order_id} is #{ppms_order} and costs #{ppms_order['Cost']}")
            rescue OpenSSL::SSL::SSLError => ssl_error
                $ppmslog.warn("Error fetching order #{ppms_order_id}: #{ssl_error}")
            rescue Net::OpenTimeout => timeout
                $ppmslog.warn("Time out fetching order #{ppms_order_id}: #{timeout}")
            end

            return ppms_order
        end
        
        ##
        # Add detail to a collection of PPMS orders by getting the invoice ids listed amongst
        # the orders out, fetching the details as returned by the "Custom invoice report - current core"
        # PPMS report and adding that detail to each order given. Adds this information as
        # "InvoiceDetail" to the PPMS order hash.
        #
        # @param |Array] ppms_orders An array of PPMS order hash objects.
        #
        def addInvoiceDetail(ppms_orders)
            invoice_ids = ppms_orders.map{ |order| order['Invoiced'] }.uniq
            
            # For each unique invoice id, get the orders in that invoice from report 1848.
                
            details_by_order_id = Hash.new
            invoice_ids.each do |invoice_id|
                if !invoice_id.nil? and !invoice_id.empty?
                    invoice_details = @ppms.getInvoicedOrder(invoice_id)
                    details_by_order_id.update(invoice_details) unless invoice_details.nil?
                end
            end
            
            # Add the invoice information for the order if it is available. Also update the
            # rate and cost.
            
            ppms_orders.each do |ppms_order|
                order_id = ppms_order['Order ref.'].to_i
                invoice = details_by_order_id[order_id]
                ppms_order['InvoiceDetail'] = invoice
                    
                unless invoice.nil?
                    final_amount = invoice['Final amount'].to_f
                    quantity = invoice['Duration (minutes booked)/Quantity'].to_f
                        
                    ppms_order['Cost'] = final_amount

                    if quantity >= 0.001
                        # To prevent divide by zero. Otherwise leave as it is.
                        ppms_order['Rate'] = final_amount / quantity
                    end
                    
                    #$ppmslog.info("Added invoice detail to order #{order_id}: #{ppms_order}")
                else
                    $ppmslog.warn("The is no invoice detail for order #{order_id}.")
                end
            end
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
                    group_struct = OpenStruct.new(:group => ppms_group, :issues => Hash.new, :time_entries => Hash.new,
                                                  :orders => Hash.new, :orders_by_issue => Hash.new)
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
            
            # Add the invoice details to the orders.
            
            combined_orders = Hash.new
            issues_by_group.values.each { |group_struct| combined_orders.update(group_struct.orders) }
                
            addInvoiceDetail(combined_orders.values)

            return issues_by_group
        end

        ##
        # Assemble time entry orders that have not been mailed and are under relevant projects
        # to the group leaders to whom those projects belong.
        #
        # @return [Hash] A hash of group leader name to status message. If the email was sent
        # without error, the status will be "Sent". If there was a failure, the status message
        # will be the text of the exception thrown when trying to send.
        #
        def sendMails()
            template_erb = loadSummaryTemplate()

            issues_by_group = assembleOrdersToGroups()

            researcher_field = CustomField.find_by(name: "Researcher Email")
            experiment_type_field = CustomField.find_by(name: "Experiment Type")

            leader_names = Hash.new

            issues_by_group.values.each do |group_struct|
                renderer = ERB.new(template_erb, nil, ">")
                summary_body = renderer.result(binding)

                # raw_data = createCSV(group_struct)
                raw_data = nil

                recipient = group_struct.group['heademail']

                if Rails.env != 'production'
                    recipient = @@testing_recipient
                end

                leader_name = group_struct.group['headname']

                begin
                    mailReport(summary_body, raw_data, recipient)

                    leader_names[leader_name] = "Sent"

                    # Set the mailed_at time on the time_entry_order objects. This will
                    # stop them being sent again.

                    timestamp = DateTime.now

                    group_struct.time_entries.values.flatten.each do |time_order|
                        time_order.mailed_at = timestamp
                        time_order.save
                    end
                rescue StandardError => error
                    $ppmslog.error("Failed to send charge summary email to #{recipient}: #{error}")

                    leader_names[leader_name] = error.message
                end
            end

            return leader_names
        end

        ##
        # Put an arbitrary date into the time entry order "mailed_at" column for all
        # entries that do not already have a mailed time and whose project is not a
        # project under the mailing roots.
        # This marks those entries as handled so they won't be picked up if the mailing
        # root changes in the future.
        #
        def markIrrelevantTimeEntries()
            mailing_project_ids = collectProjects(Setting.plugin_ppms['mailing_root'])

            TimeEntryOrder.joins(time_entry: :project).where(mailed_at: nil).where.not(projects: {id: mailing_project_ids }).update_all(mailed_at: @@irrelevant_date)
        end


        private

        ##
        # Instance version of hours_minutes, which allows it to be used in the
        # binding for creating the email body.
        #
        # @param [float] Hours as a decimal.
        # @return [string] Hours as h:mm.
        #
        def my_hours_minutes(time)
            return OrderMailer::hours_minutes(time)
        end

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
        
        ##
        # Helper for the outgoing email "contributors" column. Takes the time entry
        # orders given and assigns a total for each user who has contributed. It then
        # sorts those users into descending time logged, and returns their names in
        # that order.
        #
        # @param time_entry_orders |Array| An array of TimeEntryOrder objects.
        #
        # @return |Array| A list of user names who have contributed to the given time
        # entries.
        #
        def contributors(time_entry_orders)
            by_id = Hash.new
            time_entry_orders.each do |teo|
                user = teo.time_entry.user
                if by_id[user.id].nil?
                    by_id[user.id] = OpenStruct.new(:id => user.id, :name => user.name, :time => 0)
                end
                by_id[user.id].time = by_id[user.id].time + teo.time_entry.hours
            end
            
            by_time = by_id.values.sort_by { |s| -s.time }
            
            return by_time.map { |s| s.name }
        end

        ##
        # Load the ERB template for creating the email body.
        #
        # return [string] The content of the template file.
        #
        def loadSummaryTemplate()
            return loadTemplate("billing_summary.html.erb")
        end

        ##
        # Load a template file. The templates should be in /assets/templates.
        #
        # @param [string] template_file The name of the template file.
        # return [string] The content of the template file.
        #
        def loadTemplate(template_file)
            template_path = File.expand_path("../../assets/templates/", File.dirname(__FILE__))

            path = File.join(template_path, template_file)
            fd = File.open(path)
            begin
                template = fd.read
            ensure
                fd.close
            end

            return template
        end

        ##
        # Send the summary report to the given recipient.
        #
        # @param [string] The email body.
        # @param [string] The raw data, as CSV.
        # @param [string] The recipient's email address.
        #
        def mailReport(message_body, raw_data, recipient)
            sender = Setting.plugin_ppms['mailing_sender']
            sender = "bioinformatics@cruk.cam.ac.uk" if sender.nil? or sender.empty?

            subject = Setting.plugin_ppms['mailing_subject']
            subject = "Charges for Bioinformatics Core Support" if subject.nil? or subject.empty?

            Mail.defaults do
                delivery_method :smtp, @@smtp_settings
            end

            message = Mail.new do
                from    sender
                to      recipient
                subject subject

                html_part do
                    content_type 'text/html; charset=UTF-8'
                    body message_body
                end
            end

            if Rails.env == 'production'
                message.bcc = @@production_bcc
            end

            if not raw_data.nil?
                message.attachments['time_entries.csv'] = { :mime_type => 'text/csv; charset=UTF-8', :content => raw_data }
            end

            message.deliver!
        end
    end
end
