require 'uri'
require 'cgi'
require 'set'

require 'ppms/ppms'

class CostCode < ActiveRecord::Base
  unloadable

  @@CODE_PATTERN = /^([A-Z]{4}\/\d{3})|([A-Z]{4}\.[A-Z]{4})|([0-9]+)$/

  def self.extract_code(proj)
    # look for code in field 'Bcode'
    # If what's there doesn't match the regex, e.g. 'SWAG/001' or 'ABCD.ABCD'
    #   Look in the first word of the project name
    #   If *that* matches, use it.
    #   Otherwise, use whatever is in 'Bcode' (probably a string of digits)
    code = proj['Bcode']
    mat = code =~ @@CODE_PATTERN
    if mat.nil?
      code = nil
    end
    return code
  end

  def self.refresh(ppms)
    known_codes = {}
    seen = Set.new
    CostCode.all.each do |code|
      known_codes[code.ref] = code
    end
    projects = ppms.getProjects(true)
    projects.each do |proj|
      code = self.extract_code(proj)
      next if code.nil?
      seen.add(proj['ProjectRef'].to_i)
      cc = known_codes[proj['ProjectRef'].to_i]
      new_date =  proj['ExpirationDate']
      if ! new_date.nil?
        new_date = new_date.to_date
      end
      new_active = proj['Active'] == "True"
      if cc.nil?
        CostCode.create(name: proj['ProjectName'],
                        code: code,
                        ref: proj['ProjectRef'],
                        affiliation: proj['Affiliation'],
                        expiration: new_date,
                        active: new_active)
        $ppmslog.info("Adding cost code '#{code}'")
      else
        if cc.name != proj['ProjectName'] || cc.code != code || cc.affiliation != proj['Affiliation'] || cc.expiration != new_date || cc.active != new_active
          cc.name = proj['ProjectName']
          cc.affiliation  = proj['Affiliation']
          cc.code = code
          cc.expiration = new_date
          cc.active = new_active
          cc.save
          $ppmslog.info("Updating cost code '#{code}' (ref #{cc.code})")
        end
      end
    end
    known_codes.each do |ref,code|
      if !seen.include?(ref)
        $ppmslog.warn("Extraneous code: #{ref} #{code['code']} (removing...)")
        code.destroy
      end
    end
  end

end
