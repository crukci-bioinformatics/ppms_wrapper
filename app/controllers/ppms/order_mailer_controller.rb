class Ppms::OrderMailerController < ApplicationController

  unloadable

  def index
    @researcher_field = CustomField.where(name: "Researcher Email").take!
    @experiment_type_field = CustomField.where(name: "Experiment Type").take!

    @orders = TimeEntryOrder.where(mailed_at: nil)
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

end
