require_dependency 'ppms/initialization'

Redmine::Plugin.register :ppms do
  name 'PPMS plugin'
  author 'Gord Brown'
  description 'Wrap the API for PPMS in a Redmine plugin'
  version '0.0.2'
  url 'https://github.com/crukci-bioinformatics/ppms_wrapper'
  author_url 'http://gdbrown.org/blog'

  settings(:default => {'logfile' => '/var/log/redmine/ppms.log',
                        'api_key' => 'sBKhXbRwdPg1uEswKFYHzp5Qh2Q',
                        'api_url' => 'ppms.eu/cruk-ci-dev',
                        'project_root' => 'Research Groups',
                        'non_chargeable' => ''},
           :partial => 'settings/ppms_settings')
  menu :top_menu, :ppms, { controller: '/ppms', action: 'index' }, caption: :ppms_caption, before: :administration
end

Rails.configuration.after_initialize do
  initr = PPMS::Initializer.new
  initr.init_logger
end
