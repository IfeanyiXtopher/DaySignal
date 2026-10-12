Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]
  resource :preferences, only: %i[edit update]

  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"
end
