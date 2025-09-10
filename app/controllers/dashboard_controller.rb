class DashboardController < ApplicationController
  def index
    @users = User.all
    @total_family_points = User.sum(:points_balance)
    # TODO: Add todos and rewards when those models are created
  end
end
