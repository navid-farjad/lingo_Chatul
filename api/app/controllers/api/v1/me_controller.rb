module Api
  module V1
    # GET /api/v1/me
    # Returns the current user (anonymous or registered). Useful on app
    # startup so the client knows whether to show the sign-up CTA or the
    # logged-in profile.
    class MeController < ApplicationController
      def show
        user = current_user
        render json: {
          user_id: user.id,
          device_token: user.device_token,
          email: user.email,
          name: user.name,
          tier: user.tier,
          anonymous: user.anonymous?
        }
      end
    end
  end
end
