Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  root 'links#root'
  get '/login' => 'conferences#login'
  get '/logout' => 'conferences#logout'
  get '/doc/:id' => 'links#proxy_doc'
  get '/links/:cell' => 'links#show'
  get '/videos/:id' => 'links#video'
  get '/data/videos/:id' => 'links#video_data'
  get '/data/:doc_id/:cell' => 'links#data'
  get '/surveys' => 'surveys#index'
  post '/surveys/certificate' => 'surveys#render_certificate'
  get '/surveys/certificate' => 'surveys#certificate'
  get '/surveys/:id' => 'surveys#show'
  post '/surveys/' => 'surveys#create'
  get '/surveys/results/:id/:code' => 'surveys#results'
  get '/conferences/:id' => 'conferences#show'
end
