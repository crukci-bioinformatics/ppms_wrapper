# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
namespace :ppms do
  resources :cost_codes, only: :index
  resources :email_raven_maps, only: :index
  get :index, action: :index
  put :index, action: :show
end
#resource :ppms, only: [:show, :update]
