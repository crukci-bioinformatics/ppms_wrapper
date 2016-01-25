require_dependency 'ppms/initialization'
require_dependency 'ppms/patches'

Redmine::Plugin.register :ppms do
  name 'PPMS plugin'
  author 'Gord Brown'
  description 'Wrap the API for PPMS in a Redmine plugin'
  version '0.0.3'
  url 'https://github.com/crukci-bioinformatics/ppms_wrapper'
  author_url 'http://gdbrown.org/blog'

  settings(:default => {'logfile' => '/var/log/redmine/ppms.log',
                        'api_key' => 'jpJ1rsqIVhhc1UwbYACHnu3LAIYQnLBS',
                        'api_url' => 'ppms.eu/cruk-ci-test',
                        'project_root' => 'Research Groups; Fitzgerald',
                        'non_chargeable' => 'Experimental Design Meetings; Statistics Clinic Meeting'},
           :partial => 'settings/ppms_settings')
  menu :top_menu, :ppms, { controller: '/ppms', action: 'index' }, caption: :ppms_caption, before: :administration
end

Rails.configuration.after_initialize do
  Issue.send(:include,PPMS::IssuePatch)
  initr = PPMS::Initializer.new
  initr.init_logger
end


