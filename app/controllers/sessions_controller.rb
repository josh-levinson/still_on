class SessionsController < ApplicationController
  def destroy
    session.delete(:user_id)
    redirect_to root_path, notice: "You've been signed out."
  end
end
