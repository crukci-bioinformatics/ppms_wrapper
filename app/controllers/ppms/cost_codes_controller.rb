class Ppms::CostCodesController < ApplicationController

  unloadable

  def index
    @codes = CostCode.all
    @codes = @codes.sort { |a,b| a.code <=> b.code }
  end

end
