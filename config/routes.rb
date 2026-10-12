Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]
  resource :preferences, only: %i[edit update]
  get "geocode", to: "geocodings#search", as: :geocode
  get "geocode/reverse", to: "geocodings#reverse", as: :geocode_reverse
  get "conditions", to: "conditions#show", as: :conditions
  get "conditions/search", to: "conditions#search", as: :conditions_search
  get "conditions/nearby", to: "conditions#nearby", as: :conditions_nearby
  get "conditions/labels", to: "conditions#labels", as: :conditions_labels
  get "tiles/:layer/:z/:x/:y", to: "weather_tiles#show", as: :weather_tile,
      constraints: { layer: /temp|wind|precipitation/, z: /\d+/, x: /\d+/, y: /\d+/ }

  get "up" => "rails/health#show", as: :rails_health_check

  root "home#index"
end
