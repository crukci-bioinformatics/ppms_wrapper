require 'active_support/core_ext/hash/keys'

module PPMS

  module IssuePatch
    def self.included(base)
      base.class_eval do
        before_validation :ensure_valid_custom_fields
        def ensure_valid_custom_fields
#          $ppmslog.info("local_variables: #{local_variables}")
#          $ppmslog.info("instance_variables: #{instance_variables}")
#          $ppmslog.info("global_variables: #{global_variables}")
#          $ppmslog.info("errors: #{@errors.class}")
#          begin
#            x = ::Flash::FlashHash.from_session_value(session["flash"])
#          rescue Exception => e
#            $ppmslog.error("trapped bad flash: #{e.message}")
#          end
          email_id = CustomField.find_by(name: "Researcher Email").id
          code_id = CustomField.find_by(name: "Cost Centre").id
          returnval = true
          begin
            flds = self.custom_field_values
            flds.each do |x|
              if x.custom_field_id == email_id
                email = EmailRavenMap.find_by(email: x.value)
                if x.value.blank?
                  warnings.add(:email, "Warning: researcher email not provided")
                elsif email.nil?
#                  $ppmslog.warn("Unknown email address: '#{x.value}'")
                  warnings.add(:email, "Warning: researcher email not recognized: '#{x.value}'")
                end
              elsif x.custom_field_id == code_id
                next if x.value.nil? || x.value == ''
                code = CostCode.find_by(code: x.value)
                if code.nil?
#                  $ppmslog.warn("Unknown cost code: '#{x.value}'")
                  errors.add("cost centre"," does not exist: '#{x.value}'")
                  returnval = false
                end
              end
            end
          rescue Exception => e
            $ppmslog.error("trapped an error: #{e.message}")
          end
          return returnval
        end

        def warnings
          @warnings ||= ActiveModel::Errors.new(self)
        end

      end
    end
  end

end
