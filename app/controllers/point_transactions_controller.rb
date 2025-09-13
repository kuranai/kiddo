class PointTransactionsController < ApplicationController
  before_action :set_user

  def index
    @transactions = @user.point_transactions
                         .includes(:todo, :reward)
                         .order(created_at: :desc)
    authorize_user_access!(@user)
  end

  private

  def set_user
    @user = User.find(params[:user_id])
  end

  def authorize_user_access!(user)
    return if current_user.parent? || current_user == user
    redirect_to dashboard_path, alert: "You don't have permission to view this transaction history"
  end
end