RubyNative::Engine.routes.draw do
  resource :config, only: :show, controller: "config"
  namespace :push do
    resources :devices, only: :create
  end
  namespace :auth do
    get "start/:provider", to: "start#show", as: :start
    resource :session, only: :show
  end
end
