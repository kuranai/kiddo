class UsersController < ApplicationController
  before_action :require_login, except: [:new, :create]
  before_action :require_parent, only: [:new, :create]

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      if current_user
        redirect_to users_path, notice: "#{@user.name} has been added to the family!"
      else
        session[:user_id] = @user.id
        redirect_to dashboard_path, notice: "Welcome to the family, #{@user.name}!"
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @user = User.find(params[:id])
    authorize_user_access!(@user)
  end

  def index
    @users = User.all
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :role)
  end

  def require_parent
    return unless logged_in?
    redirect_to dashboard_path, alert: "Only parents can add new users" unless current_user.parent?
  end

  def authorize_user_access!(user)
    return if current_user.parent? || current_user == user
    redirect_to dashboard_path, alert: "You don't have permission to view this profile"
  end
end
