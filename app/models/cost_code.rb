require 'uri'
require 'cgi'
require 'set'

require 'ppms/ppms'

class CostCode < ActiveRecord::Base
  unloadable

  @@CODE_PATTERN = /^([A-Z]{4}\/\d{3})|([A-Z]{4}\.[A-Z]{4})|([0-9]+)$/

  def self.extract_code(proj)
    # Probably not needed now that we have agreement on what project codes
    # look like, but anyway... the above regular expression translates to
    # one of:
    #  a) XXXX/NNN (4 letters, a forward slash, 3 digits)
    #  b) XXXX.XXXX (4 letters, a period, 4 letters)
    #  c) NNNNNN (all digits, probably 6-7 digits long)
    # The "Bcode" field should *always* match one of these patterns.
    # The input "proj" is a hash describing a PPMS project, not a Redmine
    # ActiveRecord object.
    code = proj['Bcode']
    mat = code =~ @@CODE_PATTERN
    if mat.nil?
      code = nil
    end
    return code
  end

  def self.refresh_project(proj,seenList)
    # Add or amend (if necessary) a Redmine cost code entry, based on a PPMS
    # "Project" (cost code) hash.
    code = self.extract_code(proj)
    return if code.nil?
    ref = proj['ProjectRef'].to_i
    seenList.add(ref)
    cc = known_codes[ref]
    if cc.nil?
      CostCode.create(name: proj['ProjectName'],
                      code: code,
                      ref: proj['ProjectRef'],
                      affiliation: proj['Affiliation'])
      $ppmslog.info("Adding cost code '#{code}'")
    else
      if cc.name != proj['ProjectName'] || cc.code != code || cc.affiliation != proj['Affiliation']
        cc.name = proj['ProjectName']
        cc.affiliation  = proj['Affiliation']
        cc.code = code
        cc.save
        $ppmslog.info("Updating cost code '#{code}' (ref #{cc.code})")
      end
    end
  end

  def self.refresh(ppms)
    known_codes = {}
    seen = Set.new
    CostCode.all.each do |code|
      known_codes[code.ref] = code
    end
    projects = ppms.getProjects(true)
    projects.each do |proj|
      self.refresh_project(proj,seen)
    end
    known_codes.each do |ref,code|
      if !seen.include?(ref)
        $ppmslog.warn("Extraneous code: #{ref} #{code['code']} (removing...)")
        code.destroy
      end
    end
  end

end
