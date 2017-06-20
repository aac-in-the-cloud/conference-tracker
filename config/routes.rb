Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  get '/doc/:id' => 'links#proxy_doc'
  get '/links/:cell' => 'links#show'
  get '/data/:doc_id/:cell' => 'links#data'
end
