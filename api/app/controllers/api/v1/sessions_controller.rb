module Api
  module V1
    # Creates an anonymous user and returns a device_token the client should
    # store and send back as `X-Device-Token` on subsequent requests.
    class SessionsController < ApplicationController
      def create
        user = current_user
        render json: {
          user_id: user.id,
          device_token: user.device_token,
          tier: user.tier
        }
      end
    end
  end
end
