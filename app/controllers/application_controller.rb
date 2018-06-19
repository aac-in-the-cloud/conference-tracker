class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  before_action :check_token

  def check_token
    if cookies[:auth]
      user, token = cookies[:auth].split(/:/)
      if token == Conference.user_token(user)
        @authenticated = true
        @user = user
      end
    end
  end
end
