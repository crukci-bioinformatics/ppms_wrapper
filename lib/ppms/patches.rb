require 'active_support/core_ext/hash/keys'
require 'ppms/defaults'
require 'ppms/utils'
require 'ppms/ppms'

module PPMS

  module IssuePatch
    include Defaults

    def self.included(base)
      base.class_eval do
        before_validation :ensure_valid_custom_fields
        def ensure_valid_custom_fields
          email_id = CustomField.find_by(name: "Researcher Email").id
          code_id = CustomField.find_by(name: "Cost Centre").id
          returnval = true
          begin
            flds = self.custom_field_values
            flds.each do |x|
              if x.custom_field_id == email_id
                email = EmailRavenMap.find_by(email: x.value)
                if x.value.blank?
                  warnings.add(:email, "Researcher email not provided")
                elsif email.nil?
                  warnings.add(:email, "Researcher email not recognized: '#{x.value}'")
                end
              elsif x.custom_field_id == code_id
                next if x.value.nil? || x.value == ''
                code = CostCode.find_by(code: x.value)
                if code.nil?
#                  errors.add("cost centre"," does not exist: '#{x.value}'")
                  warnings.add("cost centre","Cost centre does not exist: '#{x.value}'")
#                  returnval = false
                end
              end
            end
          rescue StandardError => e
            $ppmslog.error("trapped an error: #{e.message}")
          end
          return returnval
        end

        def warnings
          @warnings ||= ActiveModel::Errors.new(self)
        end

        def service
          cf = ProjectCustomField.find_by(name: PPMS_SERVICE_NAME)
          proj = self.project
          srv = proj.custom_values.find_by(custom_field: cf)
          if srv.nil? || srv.value == ""
            while (! proj.parent_id.nil?) && (srv.nil? || srv.value == "")
              proj = proj.parent
              srv = proj.custom_values.find_by(custom_field: cf)
            end
          end
          if srv.nil?
            srv = Setting.plugin_ppms['default_service']
          else
            srv = srv.value
          end
          return srv
        end

      end
    end
  end

  module ProjectPatch

    def self.included(base)
      base.class_eval do

        def ppms_cost_centre
          swag = nil
          cf = CustomField.find_by(name: 'Cost Centre', type: 'ProjectCustomField')
          code = self.custom_values.find_by(custom_field: cf)
          if (! code.nil?) && (! code.value.blank?)
            swag = code.value
          else # check to see if we can find it in PPMS
            ppms = PPMS.new()
            gp = ppms.getGroup(self)
            if !gp.nil?
              ppms_code = gp["unitbcode"]
              ccFromTable = CostCode.find_by(code: ppms_code)
              if !ccFromTable.nil?
                swag = ppms_code
              end
            end
          end
          return swag
        end

      end
    end
  end

  module TimeEntryPatch
    def self.included(base)
      base.class_eval do
        validate :time_entry_not_billed

        def warnings
          @warnings ||= ActiveModel::Errors.new(self)
        end

        def time_entry_not_billed
          billed = ! TimeEntryOrder.find_by(time_entry_id: self.id).nil?
          if billed
            errors.add("time entry"," cannot be altered because it is already billed.")
          end
          if !self.issue.nil?
            cc = self.issue.cost_centre
            if ! cc.nil?
              ccObj = CostCode.find_by(code: cc)
              if ccObj.nil? 
                warnings.add("time entry","Time log was added but cost code #{cc} does not exist.")
              elsif ! ccObj.expiration.nil? && ccObj.expiration < self.spent_on
                errors.add("time entry"," cannot be added because cost code #{cc} expired on #{ccObj.expiration}")
              end
            end
          end
        end
      end
    end
  end

end
