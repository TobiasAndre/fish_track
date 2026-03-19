Rails.application.routes.draw do
  resources :customers
  devise_for :users, controllers: { sessions: "users/sessions" }
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # 
  namespace :admin do
    resources :users, only: %i[index new create edit update]
    resources :companies, only: %i[index new create edit update]
    resources :memberships
    resources :tenants, only: [:new, :create]
  end

  authenticate :user do
    resources :companies, only: [:new, :create, :edit, :update]
    resources :units
    resources :products
    resources :payment_terms
    resources :payment_methods
    resources :ponds
    resources :orders do
      member do
        patch :cancel
      end
    end
    resources :simulations do
      member do
        get :print
      end
    end
    resources :batches do
      resources :batch_stockings, only: [] do
        resources :stocking_events
      end
    end
    resource :dashboard, only: [:show]
    resources :financial_entries
    resources :employees
    resources :suppliers
    resources :customers
    resource :payroll, only: [:show, :update], controller: "payroll"

    resources :payroll_items, only: [:create, :destroy]

    root "dashboard#show"
  end
end
