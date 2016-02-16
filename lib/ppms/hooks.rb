module PPMS

  class Hooks < Redmine::Hook::Listener
    def check_for_warnings(context)
      controller = context[:controller]
      issue = context[:issue]
      if !issue.nil?
        if !issue.warnings.nil?
          issue.warnings.values.each do |v|
            controller.flash[:warning] = v[0]
          end
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
