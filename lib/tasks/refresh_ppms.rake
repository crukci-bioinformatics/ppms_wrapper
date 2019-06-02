require File.expand_path(File.dirname(__FILE__)+'/../ppms/ppms')

namespace :redmine do
  namespace :ppms do

    desc "Refresh Raven ID to email address Raven mappings from PPMS"
    task :refresh_raven => :environment do
      $ppmslog.info("Refreshing Raven IDs from PPMS")
      ppms = PPMS::PPMS.new()
      EmailRavenMap.refresh(ppms)
    end

    desc "Refresh cost codes from PPMS"
    task :refresh_cost_codes => :environment do
      $ppmslog.info("Refreshing cost codes from PPMS")
      ppms = PPMS::PPMS.new()
      CostCode.refresh(ppms)
    end

    desc "Audit group leader emails from PPMS"
    task :audit_group_leaders => :environment do
      $ppmslog.info("Checking group leader emails against PPMS")
      ppms = PPMS::PPMS.new()
      EmailRavenMap.check_groups(ppms,false)
    end

    desc "Audit group cost codes with respect to PPMS"
    task :audit_cost_codes => :environment do
      $ppmslog.info("Checking group cost codes against PPMS")
      ppms = PPMS::PPMS.new()
      CostCode.audit_group_codes(ppms,false)
    end

    desc "Carry out a refresh of all cached info from PPMS"
    task :refresh_cache_ppms => :environment do
      $ppmslog.info("Refreshing cache of PPMS data: emails, cost codes, services")
      ppms = PPMS::PPMS.new()
      $ppmslog.info("Refreshing EmailRavenMap...")
      EmailRavenMap.refresh(ppms)
      $ppmslog.info("Refreshing CostCodes...")
      CostCode.refresh(ppms)
      $ppmslog.info("Refreshing Services...")
      rec = ProjectCustomField.find_by(name: 'Service')
      services = ppms.getServices()
      names = services.map{|k,v| v["Name"]}
      rec.possible_values = names
      rec.save
      $ppmslog.info("Completed refresh")
    end

  end
end
