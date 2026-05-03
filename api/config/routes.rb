Rails.application.routes.draw do
  # Healthcheck for Kamal / load balancers
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :sessions, only: [:create]
      resources :languages, only: [:index]
      resource :stats, only: [:show]
      resources :cards, only: [:index] do
        collection do
          get :queue
        end
        resources :reviews, only: [:create]
      end
    end
  end
end
