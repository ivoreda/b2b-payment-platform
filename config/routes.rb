Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  namespace :webhooks do
    post "payment_provider", to: "payment_provider#create"
  end

  namespace :api, defaults: { format: :json } do
    namespace :v1 do
      resources :orders, only: %i[index show create], param: :reference do
        resources :payments, only: :create
      end
      resources :payments, only: :show, param: :reference
    end
  end

  namespace :dashboard do
    resources :orders, only: %i[index show], param: :reference do
      resources :payments, only: :create
    end
  end

  # Defines the root path route ("/")
  root "dashboard/orders#index"
end
