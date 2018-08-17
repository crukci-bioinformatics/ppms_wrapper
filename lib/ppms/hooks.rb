module PPMS

  class Hooks < Redmine::Hook::Listener
    def check_for_issue_warnings(context)
      controller = context[:controller]
      issue = context[:issue]
      if !issue.nil?
        if !issue.warnings.nil?
          msg = controller.flash[:warning]
          msg = "" if msg.nil?
          issue.warnings.values.each do |v|
            msg = msg + "<br>" if msg != ""
            msg = msg + v[0]
          end
#          controller.flash[:warning] = msg if msg != ""
        end
      end
      timelog = context[:timelog]
      if !timelog.nil?
        if !timelog.warnings.nil?
          msg = controller.flash[:warning]
          msg = "" if msg.nil?
          timelog.warnings.values.each do |v|
            msg = msg + "<br>" if msg != ""
            msg = msg + v[0]
          end
        end
      end
      controller.flash[:warning] = msg if msg != ""
    end
 
    def controller_issues_edit_after_save(context={})
      check_for_issue_warnings(context)
    end

    def controller_issues_new_after_save(context={})
      check_for_issue_warnings(context)
    end

    def check_for_timelog_warnings(context)
      controller = context[:controller]
      timelog = context[:time_entry]
      if !timelog.nil?
        if !timelog.warnings.nil?
          msg = controller.flash[:warning]
          msg = "" if msg.nil?
          timelog.warnings.values.each do |v|
            msg = msg + "<br>" if msg != ""
            msg = msg + v[0]
          end
          controller.flash[:warning] = msg if msg != ""
        end
      end
    end
 
    def controller_timelog_edit_after_save(context={})
      check_for_timelog_warnings(context)
    end

    def controller_timelog_new_after_save(context={})
      check_for_timelog_warnings(context)
    end

  end
end
