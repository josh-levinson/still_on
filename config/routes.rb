Rails.application.routes.draw do
  delete "sign_out", to: "sessions#destroy", as: :sign_out

  # Test-only sign-in backdoor (never available in production)
  if Rails.env.test?
    post "test/sign_in", to: "test/sessions#create", as: :test_sign_in
  end

  # Onboarding flow (new order: splash -> name -> date -> cadence -> phone -> verify -> invite)
  get  "onboarding",          to: "onboarding#splash",         as: :onboarding_splash
  get  "onboarding/name",     to: "onboarding#name",           as: :onboarding_name
  post "onboarding/name",     to: "onboarding#submit_name",    as: :onboarding_submit_name
  get  "onboarding/date",     to: "onboarding#date_step",      as: :onboarding_date
  post "onboarding/date",     to: "onboarding#submit_date",    as: :onboarding_submit_date
  get  "onboarding/cadence",  to: "onboarding#cadence",        as: :onboarding_cadence
  post "onboarding/cadence",  to: "onboarding#submit_cadence", as: :onboarding_submit_cadence
  get  "onboarding/phone",    to: "onboarding#phone",          as: :onboarding_phone
  post "onboarding/phone",    to: "onboarding#submit_phone",   as: :onboarding_submit_phone
  post "onboarding/resend",   to: "onboarding#resend_otp",     as: :onboarding_resend_otp
  get  "onboarding/verify",   to: "onboarding#verify",         as: :onboarding_verify
  post "onboarding/verify",   to: "onboarding#submit_verify",  as: :onboarding_submit_verify
  get  "onboarding/invite",   to: "onboarding#invite",         as: :onboarding_invite
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "onboarding#splash"

  # Public guest RSVP — no account required
  get  "rsvp/:token", to: "guest_rsvps#show",   as: :guest_rsvp
  post "rsvp/:token", to: "guest_rsvps#create"

  # Nested resources for groups, events, occurrences, and RSVPs
  resources :groups, param: :slug do
    resources :events do
      resources :event_occurrences do
        resources :rsvps, only: [ :create, :update, :destroy ]
      end
    end
  end

  # Shortcut for RSVPs (accessible directly via occurrence ID)
  resources :event_occurrences, only: [] do
    resources :rsvps, only: [ :create, :update, :destroy ]
  end
end
