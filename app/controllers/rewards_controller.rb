class RewardsController < ApplicationController
  before_action :set_reward, only: [ :show, :edit, :update, :destroy, :redeem ]
  before_action :require_parent, only: [ :new, :create, :edit, :update, :destroy ]

  def index
    @rewards = if params[:filter] == "affordable"
                 Reward.active.affordable_for(current_user)
    else
                 Reward.active
    end.order(:point_cost)
    @filter_type = params[:filter] || "all"
  end

  def show
  end

  def new
    @reward = Reward.new
  end

  def create
    @reward = Reward.new(reward_params)

    if @reward.save
      redirect_to rewards_path, notice: "Reward '#{@reward.name}' was created successfully!"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @reward.update(reward_params)
      redirect_to rewards_path, notice: "Reward '#{@reward.name}' was updated successfully!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    name = @reward.name
    @reward.destroy
    redirect_to rewards_path, notice: "Reward '#{name}' was deleted successfully!"
  end

  def redeem
    if @reward.affordable_by?(current_user)
      begin
        @reward.redeem_for!(current_user)
        redirect_to rewards_path, notice: "Congratulations! You redeemed '#{@reward.name}' for #{@reward.point_cost} points!"
      rescue StandardError => e
        redirect_to rewards_path, alert: "Sorry, there was an error redeeming this reward: #{e.message}"
      end
    else
      redirect_to rewards_path, alert: "You don't have enough points to redeem '#{@reward.name}'. You need #{@reward.point_cost} points but only have #{current_user.points_balance}."
    end
  end

  def toggle_active
    @reward = Reward.find(params[:id])

    unless current_user.parent?
      redirect_to rewards_path, alert: "Only parents can activate/deactivate rewards."
      return
    end

    @reward.update!(active: !@reward.active?)
    status = @reward.active? ? "activated" : "deactivated"
    redirect_to rewards_path, notice: "Reward '#{@reward.name}' has been #{status}."
  end

  private

  def set_reward
    @reward = Reward.find(params[:id])
  end

  def reward_params
    params.require(:reward).permit(:name, :description, :point_cost, :active)
  end

  def require_parent
    unless current_user.parent?
      redirect_to rewards_path, alert: "Only parents can manage rewards."
    end
  end
end
