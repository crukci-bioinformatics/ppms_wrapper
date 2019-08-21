require 'set'

require 'ppms/ppms'
require 'ppms/utils'

class EmailRavenMap < ActiveRecord::Base
  extend PPMS::Utilities
  extend Redmine::I18n

  unloadable

  def self.choose_raven(names)
    ravPat = /[a-zA-Z]+[0-9]+/
    found = names.select{|x| ravPat =~ x}
    if found.length == 1
      raven = found[0]
      $ppmslog.warn("#{__method__}: choosing '#{raven}' from #{names}")
    elsif found.length == 0
      $ppmslog.error("#{__method__}: no legal ravens in #{names}")
      raven = nil
    else
      raven = found[0]
      $ppmslog.error("#{__method__}: multiple ravens in #{names}, choosing '#{raven}'")
    end
    return raven
  end

  def self.refresh(ppms)
    known_users = {}
    seen = Set.new
    EmailRavenMap.all.each do |erm|
      known_users[erm.raven] = erm
    end
    current = Hash.new{|h,k| h[k] = []}
    raven2email = Hash.new
    ppms.listUsers.each do |raven|
      raven = raven.downcase
      seen.add(raven)
      data = ppms.getUser(raven)
      if data.nil?
        $ppmslog.warn("#{__method__}: no data for raven='#{raven}'")
      elsif !data['active'] || data['email'].blank?
        next
      else
        ekey = data['email'].downcase
        current[ekey].append(data['login'].downcase)
        raven2email[raven] = ekey
      end
    end
    current.values.each do |ravens|
      if ravens.length > 1
        raven = choose_raven(ravens)
      else
        raven = ravens[0] # won't be empty list, due to adding email, raven together
      end
      erm = known_users[raven]
      realmail = raven2email[raven]
      if erm.nil?
        begin
          EmailRavenMap.create(email: realmail, raven: raven)
          $ppmslog.info("Adding #{realmail} <--> #{raven}")
        rescue ActiveRecord::StatementInvalid
          $ppmslog.error("Failed to add email '#{realmail}', '#{raven}'")
        end
      else
        if erm.email != realmail
          erm.email = realmail
          erm.save
          $ppmslog.info("Updating #{raven} with email '#{erm.email}'")
        end
      end
    end
    known_users.each do |raven,erm|
      if !seen.include?(raven)
        $ppmslog.warn("Extraneous login '#{raven}' (#{erm.email}) (removing...)")
        erm.destroy
      end
    end
  end

  def self.check_groups(ppms,verbose=false)
    pset = collectProjects(Setting.plugin_ppms['project_root'])
    rgid = Project.find_by(name: "Research Groups").id
    pset.delete(rgid)
    Project.where(id: pset).each do |proj|
      pname = proj.name
      group = ppms.getGroup(proj,verbose=verbose)
      if group.nil?
        $ppmslog.info("Group '#{pname}' not found in PPMS")
        STDERR.printf("Info: Group '#{pname}' not found in PPMS\n")
      else
        email = group['heademail']
        if EmailRavenMap.find_by(email: email).nil?
          $ppmslog.warn("Group '#{pname}': head email '#{email}' not found")
          STDERR.printf("Group '#{pname}': head email '#{email}' not found\n")
        elsif verbose
          $ppmslog.info("Group '#{pname}': head email '#{email}'")
          STDERR.printf("Group '#{pname}': head email '#{email}'\n")
        end
      end
    end
  end

end
