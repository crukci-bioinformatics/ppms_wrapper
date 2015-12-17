require 'logger'

$: << '/opt/redmine/redmine-3.1.0/config'
$: << '/opt/redmine/redmine-3.1.0/app/models'

REDMINE_HOME = '/opt/redmine/redmine-3.1.0'
APP_PATH = REDMINE_HOME + '/config/application'

require 'boot'
require APP_PATH

module PPMS

  class Initializer

    def init
      Rails.application.require_environment!
    end

    def init_logger
      logfile = Setting.plugin_ppms['log_file']
      logfile = '/var/log/redmine/ppms.log' if logfile.nil?
      $ppmslog = ::Logger.new(logfile,10,10000000)
      $ppmslog.level = ::Logger::DEBUG
    end

  end
end
