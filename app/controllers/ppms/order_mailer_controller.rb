require 'ppms/utils'

class Ppms::OrderMailerController < ApplicationController

  include PPMS::Utilities
  
  unloadable
  
  helper_method :hours_minutes

  def index
    @researcher_field = CustomField.find_by(name: "Researcher Email")
    @experiment_type_field = CustomField.find_by(name: "Experiment Type")
    @ppms_group_field = CustomField.find_by(name: "PPMS Group ID")

    mailing_projects = collectProjects(Setting.plugin_ppms['mailing_root'])
    $ppmslog.info("Filters: #{mailing_projects}")
    
    # The above returns ids. We need to load the actual projects.
    mailing_projects = Project.where(:id => mailing_projects)
    
    mailing_projects.each do |project|
      $ppmslog.info("Project: #{project.id} #{project.name}")
    end
    
    top_level_projects = reduceProjSet(mailing_projects)
    top_level_projects.each do |project|
      $ppmslog.info("Reduced project: #{project.id} #{project.name}")
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
    
    @orders.each do |order|
      issue = order.time_entry.issue
      @issues[issue.id] = issue
      
      current = @orders_by_issue[issue.id]
      if current.nil?
        current = Array.new
        @orders_by_issue[issue.id] = current
      end
      current << order
      
      order_id = order.order_id
      unless @ppms_orders.has_value?(order_id)
        begin
          order = ppms.getOrder(order_id)
          @ppms_orders[order_id] = order
          
          cost = ppms.getPrice(order['Quanitity'], service: order['ServiceID'])
          order['Cost'] = cost
              
          $ppmslog.info("PPMS order #{order_id} is #{order} and costs #{cost}")
        rescue OpenSSL::SSL::SSLError => ssl_error
          $ppmslog.warn("Error fetching order #{order_id}: #{ssl_error}")
        rescue Net::OpenTimeout => timeout
          $ppmslog.warn("Time out fetching order #{order_id}: #{timeout}")
        end
      end
      
      project_id = order.project.id
      unless @ppms_groups_by_project_id.has_value?(project_id)
        begin
          project_with_group = get_ppms_group_project(order.project)
          if not project_with_group.nil?
            @ppms_groups_by_project_id[project_id] = ppms.getGroup(project_with_group)
            $ppmslog.info("PPMS project #{project_id} is group #{@ppms_groups_by_project_id[project_id]}")
          end
        rescue OpenSSL::SSL::SSLError => ssl_error
          $ppmslog.warn("Error fetching group for project #{project_id}: #{ssl_error}")
        rescue Net::OpenTimeout => timeout
          $ppmslog.warn("Time out fetching group for project #{project_id}: #{timeout}")
        end
      end
    end
  end
  
  def hours_minutes(time)
    hm = (time * 60).round.divmod(60)
    sprintf("%d:%02d", hm[0], hm[1])
  end
  
  def get_ppms_group_project(project)
    field_id = @ppms_group_field&.id
    
    values = project.custom_values.select{|p| p.custom_field_id == field_id}
    if values.length > 0
      return project
    end
    
    if not project.parent_id.nil?
      parent = Project.find(project.parent_id)
      return get_ppms_group_project(parent)
    end
    
    return nil
  end
end
