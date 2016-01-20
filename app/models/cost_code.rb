require 'uri'
require 'cgi'

require 'ppms/ppms'

class CostCode < ActiveRecord::Base
  unloadable

  def self.refresh(ppms)
    projects = ppms.getProjects(verbose=true)
    projects.each do |proj|
      cc = CostCode.find_by(ref: proj['ProjectRef'])
      if cc.nil?
        CostCode.create(name: proj['ProjectName'],
                        code: proj['Bcode'],
                        ref: proj['ProjectRef'])
        $ppmslog.info("Adding cost code '#{proj['Bcode']}'")
      else
        if cc.name != proj['ProjectName'] || cc.code != proj['Bcode']
          cc.name = proj['ProjectName']
          cc.code = proj['Bcode']
          cc.save
          $ppmslog.info("Updating cost code '#{proj['Bcode']}' (ref #{cc.code})")
        end
      end
    end
  end

end
