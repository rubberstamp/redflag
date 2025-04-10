Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Analysis routes
  namespace :analysis do
    get "sample-report", to: "reports#sample", as: :sample_report
  end

  # CSV Import routes
  resources :imports, only: [:new, :create] do
    collection do
      post :mapping
      post :preview
      get :progress
      get :status
      get :analysis_report, as: :report
    end
  end

  # QuickBooks Integration
  namespace :quickbooks do
    # Authentication
    get "connect", to: "auth#connect"
    get "oauth_callback", to: "auth#oauth_callback"
    get "disconnect", to: "auth#disconnect"
    get "refresh_token", to: "auth#refresh_token"
    
    # Data Analysis
    get "start_analysis", to: "data#start_analysis"
    get "permissions_error", to: "data#permissions_error"
    post "analyze", to: "data#analyze"
    get "analysis_progress", to: "data#analysis_progress"
    get "analysis_status", to: "data#analysis_status"
    get "analysis_report", to: "data#analysis_report"
    
    # API Test
    get "test_connection", to: "data#test_connection"
    
    # Profile routes
    get "profile", to: "profiles#show", as: :profile
  end
  
  # Test routes for integration tests
  if Rails.env.test?
    post "test/session", to: "test_support#setup_session"
  end

  # Pages routes
  get "pricing", to: "pages#pricing"
  get "leads/thank-you", to: "pages#lead_thank_you", as: :leads_thank_you
  get "enterprise", to: "pages#enterprise"
  
  # Product pages
  get "features", to: "pages#features"
  get "security", to: "pages#security"
  
  # Resource pages
  get "documentation", to: "pages#documentation"
  get "case-studies", to: "pages#case_studies"
  get "blog", to: "pages#blog"
  get "support", to: "pages#support"
  
  # Company pages
  get "about", to: "pages#about"
  get "careers", to: "pages#careers"
  get "contact", to: "pages#contact"
  get "partners", to: "pages#partners"
  
  # Legal pages
  get "privacy-policy", to: "pages#privacy_policy"
  get "terms-of-service", to: "pages#terms_of_service"
  get "cookie-policy", to: "pages#cookie_policy"
  
  # Lead capture and management
  resources :leads, only: [:index, :create]
  post 'leads/initial_capture', to: 'leads#initial_capture', as: :initial_lead_capture
  get 'leads/choose_import', to: 'leads#choose_import', as: :choose_import
  get 'leads/capture', to: 'leads#capture', as: :lead_capture
  get 'leads/cfo_consultation', to: 'leads#cfo_consultation', as: :cfo_consultation
  post 'leads/process_consultation', to: 'leads#process_consultation', as: :process_consultation
  
  # Administrative leads view (protected by HTTP Basic Auth)
  get 'admin/leads', to: 'leads#admin_index'
  
  # Defines the root path route ("/")
  root "pages#home"
end
