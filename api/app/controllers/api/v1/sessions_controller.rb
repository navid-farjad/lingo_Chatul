module Api
  module V1
    # POST /api/v1/sessions
    #   no body — creates an anonymous user; returns its device_token. The
    #   client should store it and send it back as X-Device-Token.
    #
    # POST /api/v1/sessions/login
    #   body: { email, password }
    #   On success returns the existing account's device_token; the client
    #   should replace its stored token with this one. Any anonymous progress
    #   on the local device is intentionally discarded.
    class SessionsController < ApplicationController
      def create
        user = current_user
        render json: serialize(user)
      end

      def login
        user = User.find_by("LOWER(email) = ?", params[:email].to_s.downcase)
        if user&.authenticate(params[:password])
          render json: serialize(user)
        else
          render json: { error: "Invalid email or password" }, status: 401
        end
      end

      private

      def serialize(user)
        {
          user_id: user.id,
          device_token: user.device_token,
          email: user.email,
          name: user.name,
          tier: user.tier
        }
      end
    end
  end
end
