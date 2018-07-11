module PPMS

  class Hooks < Redmine::Hook::Listener
    def check_for_warnings(context)
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
          controller.flash[:warning] = msg if msg != ""
        end
      end
    end
 
    def controller_issues_edit_after_save(context={})
      check_for_warnings(context)
    end

    def controller_issues_new_after_save(context={})
      check_for_warnings(context)
    end

  end
end
