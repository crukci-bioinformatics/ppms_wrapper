class TimeEntryOrder < ActiveRecord::Base
  unloadable
  belongs_to :time_entry
  
  has_one :issue, through: :time_entry
  has_one :user, through: :time_entry
  has_one :project, through: :time_entry
  has_one :activity, through: :time_entry
end
