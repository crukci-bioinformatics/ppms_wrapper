require 'logger'

require 'ppms/defaults'

module PPMS
  class Initializer
    include Defaults

    def init_logger
      logfile = Setting.plugin_ppms['log_file']
      logfile = PPMS_LOGFILE_DEFAULT if logfile.nil?
      $ppmslog = ::Logger.new(logfile,10,10000000)
      $ppmslog.level = ::Logger::DEBUG
    end

  end
end
