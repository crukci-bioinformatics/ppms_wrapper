require 'uri'
require 'cgi'

require 'ppms/ppms'

class CostCode < ActiveRecord::Base
  unloadable

  def self.refresh(ppms)
    known_codes = {}
    CostCode.all.each do |code|
      known_codes[code.ref] = code
    end
    projects = ppms.getProjects(true)
    projects.each do |proj|
      cc = known_codes[proj['ProjectRef'].to_i]
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
