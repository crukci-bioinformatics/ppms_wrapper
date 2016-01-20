require_dependency File.expand_path(File.dirname(__FILE__)+'/../ppms/ppms')

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
  end
end
