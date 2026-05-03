module Api
  module V1
    # POST /api/v1/users
    # body: { email, password, password_confirmation, name? }
    # Converts the current anonymous user (identified by X-Device-Token) into
    # a free account by attaching email + password. Progress is preserved
    # because we update the same User row that the device_token points to.
    class UsersController < ApplicationController
      def create
        user = current_user

        if user.email.present?
          return render(json: { error: "Already registered" }, status: 409)
        end

        if User.where.not(id: user.id).exists?(["LOWER(email) = ?", params[:email].to_s.downcase])
          return render(
            json: { error: "An account with this email already exists. Try logging in." },
            status: 409
          )
        end

        user.email = params[:email]
        user.password = params[:password]
        user.password_confirmation = params[:password_confirmation]
        user.name = params[:name] if params[:name].present?
        user.tier = "free"

        if user.save
          render json: serialize(user)
        else
          render json: { errors: user.errors.full_messages }, status: 422
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
