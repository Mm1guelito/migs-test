Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Authentication routes
  get 'auth/google_oauth2/callback', to: 'sessions#google_auth'
  get 'auth/linkedin/callback', to: 'sessions#linkedin_auth'
  delete 'sign_out', to: 'sessions#sign_out'
  
  # Account management routes
  delete 'accounts/:id', to: 'sessions#remove_account', as: :remove_account
  delete 'linkedin_accounts/:id', to: 'sessions#remove_linkedin_account', as: :remove_linkedin_account
  patch 'accounts/:id/toggle_calendar_sync', to: 'sessions#toggle_calendar_sync', as: :toggle_calendar_sync
  
  # Calendar routes
  get 'calendar_events', to: 'pages#calendar_events'
  
  # Static pages
  root 'pages#home'
  get 'welcome', to: 'pages#welcome'
  get 'settings', to: 'pages#settings'
  get 'past_meetings', to: 'pages#past_meetings'
  get 'upcoming', to: 'pages#upcoming'

  # OmniAuth authentication routes for Zoom and Google
  get '/auth/:provider/callback', to: 'sessions#omniauth'
  get '/auth/failure', to: redirect('/')

  resources :calendar_events, only: [] do
    member do
      patch :bot_time
      patch :toggle_bot
      get :join_and_schedule_bot
      get :media_status
    end
  end

  get 'meeting/:id', to: 'pages#meeting_detail', as: 'meeting_detail'
  
  # Social post routes
  resources :social_posts, only: [:create, :update] do
    collection do
      post :automate
    end
  end

  patch 'social_bot_config', to: 'social_bot_configs#update'

  resources :social_post_configs, only: [:create]
end
