RubyNative::Engine.routes.draw do
  resource :config, only: :show, controller: "config"
  if RubyNative.push_enabled
    namespace :push do
      resources :devices, only: :create
    end
  end
  namespace :auth do
    get "start/:provider", to: "start#show", as: :start
    resource :session, only: :show
  end
  if RubyNative.iap_enabled
    namespace :webhooks do
      resource :apple, only: :create, controller: "apple"
    end
    namespace :iap do
      resources :purchases, only: :create
      post "completions/:uuid", to: "completions#create", as: :completion
      resource :restore, only: :create
    end
  end
  namespace :screenshots do
    resource :session, only: :show, controller: "sessions"
  end
end
