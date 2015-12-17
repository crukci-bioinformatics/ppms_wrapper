require_dependency File.expand_path(File.dirname(__FILE__)+'/../ppms/ppms')

namespace :redmine do
  namespace :ppms_wrapper do

    desc "Refresh Raven ID to email address Raven mappings from PPMS"
    task :refresh_raven, [:host,:apikey] => :environment do |t,args|
      $ppmslog.info("Refreshing Raven IDs from PPMS")
      ppms = PPMS::PPMS.new(args[:host],args[:apikey])
      EmailRavenMap.refresh(ppms)
    end

    desc "Refresh cost codes from PPMS"
    task :refresh_cost_codes, [:host,:apikey] => :environment do |t,args|
      $ppmslog.info("Refreshing cost codes from PPMS")
      ppms = PPMS::PPMS.new(args[:host],args[:apikey])
      CostCode.refresh(ppms)
    end
  end
end
