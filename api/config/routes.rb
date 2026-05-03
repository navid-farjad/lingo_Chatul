Rails.application.routes.draw do
  # Healthcheck for Kamal / load balancers
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resources :sessions, only: [:create] do
        collection do
          post :login
        end
      end
      resources :users, only: [:create]
      resource :me, only: [:show], controller: "me"
      resources :languages, only: [:index]
      resource :stats, only: [:show]
      resources :cards, only: [:index] do
        collection do
          get :queue
        end
        resources :reviews, only: [:create] do
          collection do
            post :undo
          end
        end
      end
    end
  end
end
