Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  root "home#index"
  get "/products" => "products#index"
  get "/products/artwork_tips" => "products#artwork_tips", as: :artwork_tips
  get "/products/:slug" => "products#show", as: :product
  # Admin Imports Backend
  get "/admin" => redirect("/admin/imports")
  get "/admin/imports" => "admin/imports#index", as: :admin_imports
  post "/admin/imports" => "admin/imports#create"


  # Public Inquiry submissions
  post "/inquiries" => "inquiries#create", as: :inquiries

  # Admin Panel Inquiries management
  get "/admin/inquiries" => "admin/inquiries#index", as: :admin_inquiries
  get "/admin/inquiries/:id" => "admin/inquiries#show", as: :admin_inquiry
  delete "/admin/inquiries/:id" => "admin/inquiries#destroy"

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check
end
