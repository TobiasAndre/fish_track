Rails.application.routes.draw do
  devise_for :users
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")

  authenticate :user do
    resources :companies, only: [:new, :create, :edit, :update]
    resources :units
    resources :ponds
    resources :batches do
      resources :batch_events, only: [:index, :new, :create, :edit, :update, :destroy]
    end
    resource :dashboard, only: [:show]
    resources :financial_entries
    resources :employees
    resource :payroll, only: [:show, :update], controller: "payroll"

    resources :payroll_items, only: [:create, :destroy]

    root "dashboard#show"
  end
end
