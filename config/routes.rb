Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check
  post "users/sign_in", to: "users/sessions#create"
  delete "users/sign_out", to: "users/sessions#destroy"
  post "users", to: "users/registrations#create"
  post "users/confirm", to: "users/confirmations#create"
  post "users/confirm/resend", to: "users/confirmations#resend"
  get "users", to: "users#index"
  delete "users/:id", to: "users#destroy"
  
  # Password reset routes
  post "passwords", to: "users/passwords#create"
  patch "passwords", to: "users/passwords#update"
  put "passwords", to: "users/passwords#update"

  # OAuth routes
  get "/auth/google_oauth2/callback", to: "omniauth_callbacks#google_oauth2"
  get "/auth/apple/callback", to: "omniauth_callbacks#apple"
end
