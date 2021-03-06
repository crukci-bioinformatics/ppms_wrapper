require 'set'
require 'i18n'

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
    'this_fiscal'  => proc { t = Date.today; apr = Date.new(t.year,4)
                             Date.new(t.year+((t<apr)?(-1):0),4) },
    'last_fiscal'  => proc { t = Date.today; apr = Date.new(t.year,4)
                             Date.new(t.year+((t<apr)?(-2):-1),4) },
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
    'this_fiscal'  => proc { t = Date.today; apr = Date.new(t.year,4)
                             Date.new(t.year+((t<apr)?0:1),4) },
    'last_fiscal'  => proc { t = Date.today; apr = Date.new(t.year,4)
                             Date.new(t.year+((t<apr)?(-1):0),4) },
    'this_quarter' => proc { Date.today.end_of_quarter + 1 },
    'last_quarter' => proc { Date.today.beginning_of_quarter },
  }

  @@label_procs = {
    'last_12'    => proc { |x,y| "#{x.strftime('%Y %b')} to #{y.strftime('%Y %b')}" },
    'last_6'     => proc { |x,y| "#{x.strftime('%Y %b')} to #{y.strftime('%Y %b')}" },
    'last_3'     => proc { |x,y| "#{x.strftime('%Y %b')} to #{y.strftime('%Y %b')}" },
    'last_month' => proc { |x,_| "#{x.strftime('%Y %b')}" },
    'this_month' => proc { |x,_| "#{x.strftime('%Y %b')}" },
    'last_year' => proc { |x,_| "#{x.strftime('%Y')}" },
    'this_year' => proc { |x,_| "#{x.strftime('%Y')}" },
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
#          $ppmslog.error("Unexpected period description: '#{params['period_type']}'")
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
        $ppmslog.error("Unexpected date type '#{date_type}'")
        flash[:error] = l(:report_bad_date_type,:datetype => params['date_type'])
        okay = false
      end
    end
    @periods = ps_options_for_period
    return okay
  end

  def promote(ppms,project)
    iproj = project
    gp = ppms.getGroup(project)
    if gp.nil?
      while ! project.parent.nil?
        project = project.parent
        gp = ppms.getGroup(project)
        if !gp.nil?
          return gp["heademail"]
        end
      end
    else
      return gp["heademail"]
    end
    $ppmslog.info("Failed to look up group '#{iproj.name}'")
    return nil
  end

  def index
    set_up_time(params,false)
    @params = params
  end

  def time_log_commit(entries,ppms)
    allowed = semiString2List(Setting.plugin_ppms['can_commit'])
    if ! allowed.include?(User.current.login)
      flash[:error] = "Permission Denied."
      redirect_to "/ppms/index"
      return
    end
    io = StringIO.new("","w")
    io.printf("#{ l(:ppms_report_title) }: #{@intervaltitle}\n\n")
    io.printf("OrderID,ServiceID,Login,Quantity,Bcode,CompleteDate,User,Code,Issues\n")
    entries.values.each do |ent|
      issues = ent[:iss].to_a.map{|x| "#{x}"}.join(" ")
      issues_comment = "Redmine: #{issues}"
      begin
        quant = ent[:quant].round(2)
        result = ppms.submitOrder(ent[:serviceid],ent[:login],quant,ent[:bcode],ent[:date],issues_comment)
        ent[:logs].to_a.each do |id|
          TimeEntryOrder.create(time_entry_id: id, order_id: result)
        end
        io.printf("#{result},#{ent[:serviceid]},#{ent[:login]},#{quant},#{ent[:bcode]},#{ent[:date]},#{ent[:email]},#{ent[:swag]},#{issues}\n")
      rescue PPMS::PPMS_Error => pe
        $ppmslog.error(pe.message)
        $ppmslog.error(pe.backtrace.join("\n"))
      end
    end 
    fn = (l(:ppms_report_title)+"_"+@intervaltitle).gsub(" ","_")+".csv"
    send_data(io.string,filename: fn)
  end


  def show
    # to send to PPMS:
    #   bcode (from swag)
    #   serviceID
    #   login
    #   quantity
    #   completeDate
    # for user convenience:
    #   user email
    #   list of issues covered (links)
    #   list of time log entries (links)
    #   service name
    #   swag code
    #   whether login was promoted to group leader due to missing/unknown email
    # for orphans: time log id, issue id, user (if any), code (if any), hours
    #
    # separate out billed and not yet billed
    okay = set_up_time(params,true)
    if !okay
      redirect_to "/ppms/index"
      return
    end
    ppms = PPMS::PPMS.new()
    serviceHash = ppms.getServices()
    services = serviceHash.transform_values{|v| v["Service id"]}
    projects = collectProjects(Setting.plugin_ppms['project_root'])
    nc_activities = collectActivities(Setting.plugin_ppms['non_chargeable'])

    @entries = Hash.new
    @orphans = Hash.new
    @missingIssue = Array.new
    @leaders = Hash.new
    keyset = Set.new
    @billed = Hash.new
    costCodes = Hash.new
    TimeEntry.where(spent_on: @from..(@to-1)).includes(:issue).includes(:project).each do |log|
      next unless projects.include? log.project_id
      next if nc_activities.include? log.activity_id
      iss = log.issue
      proj = log.project
      if iss.nil?
        @missingIssue << log
        next
      end
      who = iss.researcher
      srvc = services[iss.service()]
      promoted = false
      if who.blank? || EmailRavenMap.find_by(email: who).nil?
        if @leaders.include? log.project_id
          who = @leaders[log.project_id]
        else
          who = promote(ppms,log.project)
          @leaders[log.project_id] = who
        end
        promoted = true if ! who.nil?
      end
      erm = EmailRavenMap.find_by(email: who) unless who.nil?
      raven = (who.nil? || erm.nil?) ? nil : erm.raven
      swag = iss.cost_centre
      if !costCodes.include?(swag)
        begin
          costCodes[swag] = CostCode.find_by(code: swag)
        rescue
          costCodes[swag] = nil
        end
      end
      cc = costCodes[swag]
      code = cc&.code
      if raven.nil? || code.nil?
        if @orphans.include? iss.id
          @orphans[iss.id][:quant] += log.hours
        else
          if raven.nil? && code.nil?
            reason = "no PPMS user found; no valid cost code found"
          elsif raven.nil?
            reason = "no PPMS user found"
          elsif code.nil?
            reason = "no valid cost code found"
          else
            # but then how did we get here at all?
            reason = "unknown reason"
          end
          @orphans[iss.id] = {issue: iss.id,who: who,swag: swag,quant: log.hours, project: proj, promoted: promoted,reason: reason}
        end
      else
        key = "#{raven}_#{code}_#{srvc}_#{iss.id}"
        teo = TimeEntryOrder.find_by(time_entry_id: log.id)
        if ! teo.nil?
          id = key
          if @billed.include?(id)
            @billed[id][:quant] = @billed[id][:quant] + log.hours
            @billed[id][:date] = [@billed[id][:date], log.spent_on].max
            @billed[id][:iss].add(iss.id)
            @billed[id][:logs].add(log.id)
            @billed[id][:project].add(proj)
          else
            @billed[id] = {bcode: code, serviceid: services[iss.service], login: raven,
                           quant: log.hours, date: log.spent_on, email: who,
                           iss: Set.new([iss.id]), logs: Set.new([log.id]),
                           project: Set.new([proj]),
                           swag: swag, key: key, promoted: promoted,
                           teo: teo.order_id}
          end
        else
          if keyset.include?(key)
            @entries[key][:quant] = @entries[key][:quant] + log.hours
            @entries[key][:date] = [@entries[key][:date], log.spent_on].max
            @entries[key][:iss].add(iss.id)
            @entries[key][:logs].add(log.id)
            @entries[key][:project].add(proj)
          else
            @entries[key] = {bcode: code, serviceid: services[iss.service], login: raven,
                             quant: log.hours, date: log.spent_on, email: who,
                             iss: Set.new([iss.id]), logs: Set.new([log.id]),
                             project: Set.new([proj]),
                             swag: swag, key: key, promoted: promoted}
            keyset.add(key)
          end
        end
      end
    end

    @keys = keyset.to_a.sort{|a,b| @entries[a][:swag] <=> @entries[b][:swag]}
    @warnings = []
    @thresh = Setting.plugin_ppms['warning_threshold'].to_i
    toBillTotal = 0
    @keys.each do |k|
      e = @entries[k]
      e[:project] = reduceProjSet(e[:project])
      if e[:quant] > @thresh
        @warnings.append([e[:quant].round(2),e[:project].to_a()[0],e[:swag]])
      end
      cc = costCodes[e[:swag]]
      begin
        cost = ppms.getPrice(e[:quant], affiliation: cc.affiliation, costCode: cc.code, service: e[:serviceid])
        toBillTotal += cost
        e[:price] = sprintf("%.2f",cost)
        e[:rate] = sprintf("%.2f",ppms.getRate(affiliation: cc.affiliation, service: e[:serviceid])[0].price)
        e[:affil] = ppms.affiliationName(cc.affiliation)
      rescue => ex
        e[:price] = 0
        e[:rate] = -99
        e[:affil] = "missing"
      end
    end
    
    @toBillTotal = sprintf("%.2f",toBillTotal)
    billedTotal = 0
    @billed.keys().each do |k|
      e = @billed[k]
      cc = costCodes[e[:swag]]
      e[:project] = reduceProjSet(e[:project])
      begin
        cost = ppms.getPrice(e[:quant], affiliation: cc.affiliation, costCode: cc.code, service: e[:serviceid])
        billedTotal += cost
        e[:price] = sprintf("%.2f",cost)
        e[:rate] = sprintf("%.2f",ppms.getRate(affiliation: cc.affiliation, service: e[:serviceid])[0].price)
        e[:affil] = ppms.affiliationName(cc.affiliation)
      rescue => ex
        e[:price] = 0
        e[:rate] = -99
        e[:affil] = "missing"
      end
    end
    
    @billedTotal = sprintf("%.2f",billedTotal)
    @bnums = @billed.keys.sort
    @params = params
    if @params['format'] == 'csv'
      time_log_commit(@entries,ppms)
    else
      render "show"
    end
  end

  def audit_project_codes
    @proj_cost_code_bad = Set.new
    Project.all.each do |proj|
      cc = proj.ppms_cost_centre
      next if cc.nil?
        
      o = CostCode.find_by(code: cc)
      if o.nil?
        @proj_cost_code_bad.add(proj)
      end
    end
  end

  def update_service_names(ppms)
    rec = ProjectCustomField.find_by(name: 'Service')
    services = ppms.getServices()
    names = services.map{|k,v| v["Name"]}
    rec.possible_values = names
    rec.save
  end
   
  def update
    ppms = PPMS::PPMS.new()
    $ppmslog.info("Refreshing Raven IDs from PPMS")
    EmailRavenMap.refresh(ppms)
    $ppmslog.info("Refreshing cost codes from PPMS")
    CostCode.refresh(ppms)
    $ppmslog.info("Updating services from PPMS")
    update_service_names(ppms)

    open = IssueStatus.where(is_closed: false).map{|x| x.id} 
    pset = collectProjects(Setting.plugin_ppms['project_root'])
    email_needed_txt = Setting.plugin_ppms['user_email_required']
    if !email_needed_txt.nil? and !email_needed_txt.blank?
      email_needed = collectProjects(Setting.plugin_ppms['user_email_required'])
    else
      email_needed = nil
    end
    @codes_checked = Set.new
    @iss_code_missing = Set.new
    @iss_code_bad = Set.new
    @iss_email_missing = Set.new
    @iss_email_bad = Set.new
    Issue.where(status: open).where(project_id: pset).each do |iss|
      code = iss.cost_centre
      if code.nil?
        @iss_code_missing.add(iss)
      elsif !@codes_checked.include?(code)
        code_obj = CostCode.find_by(code: code)
        if code_obj.nil?
          @iss_code_bad.add(iss)
        else
          @codes_checked.add(code)
        end
      end
      email = iss.researcher
      email = email.downcase unless email.nil?
      if email_needed.nil? or email_needed.include?(iss.project_id)
        if email.nil?
          @iss_email_missing.add(iss)
        elsif EmailRavenMap.find_by(email: email).nil?
          @iss_email_bad.add(iss)
        end
      end
    end
    audit_project_codes
  end

end
