Spree::Core::Engine.routes.draw do
  namespace :admin do
    resources :csv_orders
  end
end
