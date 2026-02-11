RubyNative::Engine.routes.draw do
  resource :config, only: :show, controller: "config"
  namespace :push do
    resources :devices, only: :create
  end
end
