Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  root "home#index"
  get "/products" => "products#index"
  get "/products/artwork_tips" => "products#artwork_tips", as: :artwork_tips
  get "/products/:id/:slug" => "products#show", as: :product

  # Public Inquiry submission (email only, no DB)
  post "/inquiries" => "inquiries#create", as: :inquiries

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
