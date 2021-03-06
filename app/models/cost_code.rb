require 'uri'
require 'cgi'
require 'set'

require 'ppms/ppms'
require 'ppms/utils'

class CostCode < ActiveRecord::Base
  extend PPMS::Utilities
  unloadable

  @@CODE_PATTERN = /^([A-Z]{4}\/\d{3})|([A-Z]{4}\.[A-Z]{4})|([0-9]+)$/

  def self.extract_code(account)
    # look for code in field 'bcode'
    # If what's there doesn't match the regex, e.g. 'SWAG/001' or 'ABCD.ABCD'
    #   Look in the first word of the project name
    #   If *that* matches, use it.
    #   Otherwise, use whatever is in 'bcode' (probably a string of digits)
    code = account['bcode']
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
      known_codes[code.code] = code
    end
    accounts = ppms.getAccounts()
    accounts.each do |account|
      code = self.extract_code(account)
      next if code.nil?
      seen.add(code)
      cc = known_codes[code]
      new_date = account['expirationDatePost']
      if ! new_date.nil?
        new_date = new_date.to_date
      end
      new_active = account['active'] == "true"
      if cc.nil?
        CostCode.create(name: account['descriptionShort'],
                        code: code,
                        ref: account['rowNum'],
                        affiliation: account['affiliation'],
                        expiration: new_date,
                        active: new_active)
        $ppmslog.info("Adding cost code '#{code}'")
      else
        if cc.code != code || cc.affiliation != account['affiliation'] || cc.expiration != new_date || cc.active != new_active
          cc.affiliation = account['affiliation']
          cc.code = code
          cc.expiration = new_date
          cc.active = new_active
          cc.save
          $ppmslog.info("Updating cost code '#{code}'")
        end
      end
    end
    known_codes.each do |code,cc|
      if !seen.include?(code)
        $ppmslog.warn("Extraneous code: #{cc['code']} (removing...)")
        cc.destroy
      end
    end
  end

  def self.audit_group_codes(ppms,verbose=false)
    pset = collectProjects(Setting.plugin_ppms['project_root'])
    rgid = Project.find_by(name: "Research Groups").id
    pset.delete(rgid)
    ccIDfield = CustomField.find_by(name: 'Cost Centre')
    Project.where(id: pset).each do |proj|
      gp = ppms.getGroup(proj)
      cc = proj.ppms_cost_centre
      if gp.nil?
        if !cc.nil?
          $ppmslog.warn("Group '#{proj.name}': not in PPMS; cc = '#{cc}' (explicitly set)")
          STDERR.printf("Group '#{proj.name}': not in PPMS; cc = '#{cc}' (explicitly set)\n")
#        else
#          $ppmslog.warn("Group '#{proj.name}': not in PPMS; no cc set")
#          STDERR.printf("Group '#{proj.name}': not in PPMS; no cc set\n")
        end
      else
        ppms_code = gp["unitbcode"]
        ccFromTable = CostCode.find_by(code: ppms_code)
        if ccFromTable.nil?
          STDERR.printf("Group '#{proj.name}': ERROR: ppms_code '#{ppms_code}' not found in CostCodes\n")
          ppms_code = nil
        end
        if cc.nil?
          $ppmslog.warn("Group '#{proj.name}': PPMS cc: '#{ppms_code}'; no cc explicitly set")
          STDERR.printf("Group '#{proj.name}': PPMS cc: '#{ppms_code}'; no cc explicitly set\n")
        else
          if cc == ppms_code
            $ppmslog.info("Group '#{proj.name}': PPMS cc: '#{ppms_code}'; local cc matches")
            STDERR.printf("Group '#{proj.name}': PPMS cc: '#{ppms_code}'; local cc matches\n")
          else
            $ppmslog.info("Group '#{proj.name}': MISMATCH PPMS cc: '#{ppms_code}'; local cc '#{cc}'")
            STDERR.printf("Group '#{proj.name}': MISMATCH PPMS cc: '#{ppms_code}'; local cc '#{cc}'\n")
          end
        end
      end
    end
  end
end
