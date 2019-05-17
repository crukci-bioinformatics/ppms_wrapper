require File.expand_path(File.dirname(__FILE__)+'/../ppms/ppms')

namespace :redmine do
  namespace :ppms do

    desc "Probe PPMS ID lookup"
    task :issue2user, [:iss_id] => :environment do |t,args|
      id = args[:iss_id].to_i
      if id == 0
        $stderr.write("Issue not supplied, or not a number, or 0: '#{args[:iss_id]}'\n")
        exit
      end
      $stderr.write("Looking up PPMS user for issue #{id}\n")
      ppms = PPMS::PPMS.new()
      begin
        iss = Issue.find(id)
      rescue ActiveRecord::RecordNotFound
        $stderr.write("Unknown issue id: #{id}\n")
        exit
      end
      user = ppms.issue2User(iss,verbose: true)
      if !user.nil?
        $stdout.print("PPMS login: #{user['login']}  #{user['fname']} #{user['lname']}  #{user['email']}\n")
      else
        $stdout.print("Failed to look up user from #{iss.id}.\n")
      end
    end

  end
end
