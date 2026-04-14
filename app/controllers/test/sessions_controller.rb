module Test
  class SessionsController < ApplicationController
    skip_before_action :verify_authenticity_token, raise: false

    def create
      session[:user_id] = params[:user_id]
      head :ok
    end
  end
end
