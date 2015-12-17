require_dependency 'ppms/initialization'

Redmine::Plugin.register :ppms do
  name 'PPMS plugin'
  author 'Gord Brown'
  description 'Wrap the API for PPMS in a Redmine plugin'
  version '0.0.1'
  url 'https://github.com/crukci-bioinformatics/ppms_wrapper'
  author_url 'http://gdbrown.org/blog'

  settings(:default => {'logfile' => '/var/log/redmine/ppms.log'},
           :partial => 'settings/ppms_settings')
end

Rails.configuration.after_initialize do
  initr = PPMS::Initializer.new
  initr.init_logger
end
