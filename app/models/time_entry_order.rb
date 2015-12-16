class TimeEntryOrder < ActiveRecord::Base
  unloadable
  belongs_to :time_entry
end
