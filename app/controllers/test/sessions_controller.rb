return unless Rails.env.test?

class Test::SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    session[:user_id] = params[:user_id].to_i
    head :ok
  end
end
