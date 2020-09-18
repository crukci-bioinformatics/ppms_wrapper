class Ppms::OrderMailerController < ApplicationController

  unloadable

  def index
    @orders = TimeEntryOrder.where(mailed_at: nil)
  end

end
