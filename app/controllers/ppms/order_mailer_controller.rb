require 'ppms/utils'

class Ppms::OrderMailerController < ApplicationController

  include PPMS::Utilities
  
  unloadable
  
  helper_method :hours_minutes

  def index
    @researcher_field = CustomField.where(name: "Researcher Email").take!
    @experiment_type_field = CustomField.where(name: "Experiment Type").take!

    mailing_projects = collectProjects(Setting.plugin_ppms['mailing_root'])
    $ppmslog.info("Filters: #{mailing_projects}")

    @orders = TimeEntryOrder.where(mailed_at: nil)
    $ppmslog.info("Orders before filter: #{@orders.size}")
    @orders = @orders.select { |order| mailing_projects.include? order.time_entry.project.id }
    $ppmslog.info("Orders after filter: #{@orders.size}")
         
    #@orders.each do |order|
    #  $ppmslog.warn("TEO #{order.id} is issue #{order.time_entry.issue.id} - #{order.time_entry.issue.subject}")
    #end
    
    @issues = Hash.new
    @orders_by_issue = Hash.new
    
    @orders.each do |order|
      issue = order.time_entry.issue
      @issues[issue.id] = issue
      
      current = @orders_by_issue[issue.id]
      if current.nil?
        current = Array.new
        @orders_by_issue[issue.id] = current
      end
      current << order
    end
  end
  
  def hours_minutes(time)
    hm = (time * 60).round.divmod(60)
    sprintf("%d:%02d", hm[0], hm[1])
  end
end
