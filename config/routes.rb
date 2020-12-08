# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
namespace :ppms do
  resources :cost_codes, only: :index
  resources :email_raven_maps, only: :index
  resources :order_mailer, only: [:index, :create]
  get :index, action: :index
  put :index, action: :show
  post :index, action: :create
  patch :index, action: :update
end
#resource :ppms, only: [:show, :update]
