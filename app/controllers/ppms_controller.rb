require 'ppms/utils'

class PpmsController < ApplicationController

  include PPMS::Utilities

  unloadable

  @@from_procs = {
    'last_12'      => proc { Date.today.beginning_of_month << 12 },
    'last_6'       => proc { Date.today.beginning_of_month << 6 },
    'last_3'       => proc { Date.today.beginning_of_month << 3 },
    'last_month'   => proc { Date.today.beginning_of_month << 1 },
    'this_month'   => proc { Date.today.beginning_of_month },
    'this_year'    => proc { Date.today.beginning_of_year },
    'last_year'    => proc { Date.today.beginning_of_year << 12 },
    'this_fiscal'  => proc { t = Date.today; apr = Date.new(year=t.year,month=4)
                             Date.new(year=t.year+((t<apr)?(-1):0),month=4) },
    'last_fiscal'  => proc { t = Date.today; apr = Date.new(year=t.year,month=4)
                             Date.new(year=t.year+((t<apr)?(-2):-1),month=4) },
    'this_quarter' => proc { Date.today.beginning_of_quarter },
    'last_quarter' => proc { Date.today.beginning_of_quarter << 3 },
  }

  @@to_procs = {
    'last_12'      => proc { Date.today.beginning_of_month },
    'last_6'       => proc { Date.today.beginning_of_month },
    'last_3'       => proc { Date.today.beginning_of_month },
    'last_month'   => proc { Date.today.beginning_of_month },
    'this_month'   => proc { Date.today.end_of_month + 1 },
    'this_year'    => proc { Date.today.end_of_year + 1 },
    'last_year'    => proc { Date.today.beginning_of_year },
    'this_fiscal'  => proc { t = Date.today; apr = Date.new(year=t.year,month=4)
                             Date.new(year=t.year+((t<apr)?0:1),month=4) },
    'last_fiscal'  => proc { t = Date.today; apr = Date.new(year=t.year,month=4)
                             Date.new(year=t.year+((t<apr)?(-1):0),month=4) },
    'this_quarter' => proc { Date.today.end_of_quarter + 1 },
    'last_quarter' => proc { Date.today.beginning_of_quarter },
  }

  @@label_procs = {
    'last_12'    => proc { |x,y| "#{x.strftime('%Y %b')} to #{y.strftime('%Y %b')}" },
    'last_6'     => proc { |x,y| "#{x.strftime('%Y %b')} to #{y.strftime('%Y %b')}" },
    'last_3'     => proc { |x,y| "#{x.strftime('%Y %b')} to #{y.strftime('%Y %b')}" },
    'last_month' => proc { |x,y| "#{x.strftime('%Y %b')}" },
    'this_month' => proc { |x,y| "#{x.strftime('%Y %b')}" },
    'last_year' => proc { |x,y| "#{x.strftime('%Y')}" },
    'this_year' => proc { |x,y| "#{x.strftime('%Y')}" },
    'last_fiscal' => proc { |x,y| "#{x.strftime('%Y %b')} to #{y.strftime('%Y %b')}" },
    'this_fiscal' => proc { |x,y| "#{x.strftime('%Y %b')} to #{y.strftime('%Y %b')}" },
    'last_quarter' => proc { |x,y| "#{x.strftime('%Y %b')} to #{y.strftime('%Y %b')}" },
    'this_quarter' => proc { |x,y| "#{x.strftime('%Y %b')} to #{y.strftime('%Y %b')}" },
  }

  def ps_options_for_period
    return [
      [l(:label_last_month),"last_month"],
      [l(:label_this_month),"this_month"],
      [l(:label_last_12),"last_12"],
      [l(:label_last_6),"last_6"],
      [l(:label_last_3),"last_3"],
      [l(:label_this_year),"this_year"],
      [l(:label_last_year),"last_year"],
      [l(:label_this_fiscal),"this_fiscal"],
      [l(:label_last_fiscal),"last_fiscal"],
      [l(:label_this_quarter),"this_quarter"],
      [l(:label_last_quarter),"last_quarter"]]
  end

  def set_up_time(params,update)
    okay = true
    if update
      if ! params.has_key? "date_type"
        flash[:warning] = l(:report_choose_radio_button)
        okay = false
      elsif params['date_type'] == '1'
        @to = @@to_procs[params['period_type']].call
        @from = @@from_procs[params['period_type']].call
        @intervaltitle = @@label_procs[params['period_type']].call(@from,@to)
#        else
#          $pslog.error("Unexpected period description: '#{params['period_type']}'")
#          flash[:error] = l(:report_bad_period_descr,:period => params['period_type'])
#          okay = false
#        end
        if okay
          params['report_date_to'] = "%s" % @to
          params['report_date_from'] = "%s" % @from
        end
      elsif params['date_type'] == '2'
        begin
          if !params.has_key?('report_date_from') or params['report_date_from'].blank?
            flash[:warning] = l(:report_choose_from_date)
            okay = false
          else
            @from = Date.parse(params['report_date_from'])
          end
          if !params.has_key?('report_date_to') or params['report_date_to'].blank?
            flash[:notice] = l(:report_choose_to_date)
            @to = Date.today
          else
            @to = Date.parse(params['report_date_to'])
          end
          if okay
            @intervaltitle = "#{@from.strftime('%Y %b %-d')} to #{@to.strftime('%Y %b %-d')}"
          end
        rescue ArgumentError
          flash[:error] = l(:report_date_format_error)
          okay = false
        end
      else
        $pslog.error("Unexpected date type '#{date_type}'")
        flash[:error] = l(:report_bad_date_type,:datetype => params['date_type'])
        okay = false
      end
    end
    @periods = ps_options_for_period
    return okay
  end

  def index
    set_up_time(params,false)
    @params = params
  end

  def show
    set_up_time(params,true)
    ppms = PPMS::PPMS.new()
    service = ppms.getServiceID()
    projects = collectProjects(Setting.plugin_ppms['project_root'])
    nc_activities = collectActivities(Setting.plugin_ppms['non_chargeable'])

    @entries = Array.new()
    TimeEntry.where(spent_on: @from..(@to-1)).includes(:issue).order(:spent_on).each do |log|
      next unless projects.include? log.project_id
      next if nc_activities.include? log.activity_id
      iss = log.issue
      begin
        login = EmailRavenMap.find_by(iss.researcher).raven
      rescue
        login = "unknown"
      end
      @entries.push([service,login,log.hours,iss.cost_centre,true,true,log.spent_on])
    end
    @params = params
  end

end
