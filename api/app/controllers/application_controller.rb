class ApplicationController < ActionController::API
  # Pulls the device token from the X-Device-Token header (or creates a fresh
  # anonymous user) and exposes `current_user` to subclasses.
  def current_user
    @current_user ||= find_or_create_user_from_token
  end

  private

  def find_or_create_user_from_token
    token = request.headers["X-Device-Token"].presence
    if token
      User.find_by(device_token: token) || create_anonymous_user(token)
    else
      create_anonymous_user
    end
  end

  def create_anonymous_user(token = nil)
    User.create!(device_token: token, tier: "anonymous")
  end
end
