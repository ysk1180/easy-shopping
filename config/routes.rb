Rails.application.routes.draw do
  post '/callback' => 'linebots#callback'
  post '/shopping-memo/callback' => 'shopping_memos#callback'
  post '/rakuten/callback' => 'rakutens#callback'
end
