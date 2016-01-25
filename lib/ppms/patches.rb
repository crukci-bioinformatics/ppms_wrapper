module PPMS

  module IssuePatch
    def self.included(base)
      base.class_eval do
        before_validation :ensure_valid_custom_fields
        def ensure_valid_custom_fields
          $ppmslog.info("In validation code...")
          email_id = CustomField.find_by(name: "Researcher Email").id
          code_id = CustomField.find_by(name: "Cost Centre").id
          returnval = true
          begin
            flds = self.custom_field_values
            flds.each do |x|
              $ppmslog.info("#{x.custom_field_id} == #{x.value}")
              if x.custom_field_id == email_id
                email = EmailRavenMap.find_by(email: x.value)
                if email.nil?
                  $ppmslog.warn("Unknown email address: '#{x.value}'")
                  errors.add(:email, " Error: email address unknown: '#{x.value}'")
                  returnval = false
                end
              elsif x.custom_field_id == code_id
                code = CostCode.find_by(code: x.value)
                if code.nil?
                  $ppmslog.warn("Unknown cost code: '#{x.value}'")
                  errors.add(:cost_code," Error: cost code unknown: '#{x.value}'")
                  returnval = false
                end
              end
            end
          rescue Exception => e
            $ppmslog.error("trapped an error: #{e.message}")
          end
          return returnval
        end
      end
    end
  end

end
