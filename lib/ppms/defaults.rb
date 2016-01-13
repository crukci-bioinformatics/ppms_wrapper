module PPMS
  module Defaults

    PPMS_LOGFILE_DEFAULT = '/var/log/redmine/ppms.log' unless defined? PPMS_LOGFILE_DEFAULTS
    PPMS_API_URL_DEFAULT = 'ppms.eu/cruk-ci-dev' unless defined? PPMS_API_URL_DEFAULT
    PPMS_API_KEY_DEFAULT = 'sBKhXbRwdPg1uEswKFYHzp5Qh2Q' unless defined? PPMS_API_KEY_DEFAULT
    
  end
end
