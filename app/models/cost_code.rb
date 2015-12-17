require 'uri'
require 'cgi'

require 'ppms/ppms'

class CostCode < ActiveRecord::Base
  unloadable

  def self.refresh(ppms)
    projects = ppms.getProjects(verbose=true)
    projects.each do |proj|
      next if CostCode.find_by(ref: proj['ProjectRef'])
      CostCode.create(name: proj['ProjectName'],
                      code: proj['Bcode'],
                      ref: proj['ProjectRef'])
      $ppmslog.info("Adding cost code '#{proj['Bcode']}'")
    end
  end

end
