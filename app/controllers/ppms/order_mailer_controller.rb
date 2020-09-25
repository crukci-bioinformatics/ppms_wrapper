require 'ppms/utils'

class Ppms::OrderMailerController < ApplicationController

  include PPMS::Utilities
  
  unloadable
  
  helper_method :hours_minutes

  def index
    @researcher_field = CustomField.find_by(name: "Researcher Email")
    @experiment_type_field = CustomField.find_by(name: "Experiment Type")

    mailing_projects = collectProjects(Setting.plugin_ppms['mailing_root'])
    #$ppmslog.info("Filters: #{mailing_projects}")
    
    # The above returns ids. We need to load the actual projects.
    mailing_projects = Project.where(:id => mailing_projects)
    
    mailing_projects.each do |project|
      #$ppmslog.info("Project: #{project.id} #{project.name}")
    end
    
    top_level_projects = reduceProjSet(mailing_projects)
    top_level_projects.each do |project|
      #$ppmslog.info("Reduced project: #{project.id} #{project.name}")
    end

    @orders = TimeEntryOrder.where(mailed_at: nil)
    $ppmslog.info("Orders before filter: #{@orders.size}")
    @orders = @orders.select { |order| mailing_projects.include? order.time_entry.project }
    $ppmslog.info("Orders after filter: #{@orders.size}")
         
    
    #@orders.each do |order|
    #  $ppmslog.warn("TEO #{order.id} is issue #{order.time_entry.issue.id} - #{order.time_entry.issue.subject}")
    #end
    
    ppms = PPMS::PPMS.new()
      
    @issues = Hash.new
    @orders_by_issue = Hash.new
    @ppms_orders = Hash.new
    @ppms_groups_by_project_id = Hash.new
    
    @orders.each do |time_order|
      issue = time_order.time_entry.issue
      @issues[issue.id] = issue
      
      current = @orders_by_issue[issue.id]
      if current.nil?
        current = Array.new
        @orders_by_issue[issue.id] = current
      end
      current << time_order

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
          project = @ppms_groups_by_project_id[project_id]
          
          ppms_order = ppms.getOrder(order_id)[order_id.to_s]
          @ppms_orders[order_id] = ppms_order
          
          begin
            cost = ppms.getPrice(ppms_order['Quantity'].to_f, affiliation: project['affiliation'], service: ppms_order['ServiceID'])
            ppms_order['Cost'] = cost
          rescue PPMS::PPMS_Error => failure
            ppms_order['Cost'] = "Unavailable"
            $ppmslog.error(failure.message)
          end
              
          $ppmslog.info("PPMS order #{order_id} is #{ppms_order} and costs #{cost}")
        rescue OpenSSL::SSL::SSLError => ssl_error
          $ppmslog.warn("Error fetching order #{order_id}: #{ssl_error}")
        rescue Net::OpenTimeout => timeout
          $ppmslog.warn("Time out fetching order #{order_id}: #{timeout}")
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
    
    if group.nil? and !project.parent_id.nil?
      parent = Project.find(project.parent_id)
      group = get_ppms_group_for_project(ppms, parent)
    end
    
    return group
  end
end
