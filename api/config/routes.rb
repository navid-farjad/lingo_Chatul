Rails.application.routes.draw do
  # Healthcheck for Kamal / load balancers
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resource :session, only: [:create]
      resources :cards, only: [:index] do
        collection do
          get :queue
        end
        resources :reviews, only: [:create]
      end
    end
  end
end
