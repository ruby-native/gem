RubyNative::Engine.routes.draw do
  resource :config, only: :show, controller: "config"
  namespace :push do
    resources :devices, only: :create
  end
  namespace :auth do
    get "start/:provider", to: "start#show", as: :start
    resource :session, only: :show
  end
  namespace :webhooks do
    resource :apple, only: :create, controller: "apple"
  end
  namespace :iap do
    resources :purchases, only: :create
    post "completions/:uuid", to: "completions#create", as: :completion
  end
end
