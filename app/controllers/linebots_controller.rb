class LinebotsController < ApplicationController
  require 'line/bot'
  require 'bitly'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery :except => [:callback]

  def callback
    body = request.body.read
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
      error 400 do 'Bad Request' end
    end
    events = client.parse_events_from(body)
    events.each do |event|
      case event
      when Line::Bot::Event::Message
        case event.type
        when Line::Bot::Event::MessageType::Text
          input = event.message['text']
          # デバックログ出力するために記述
          Amazon::Ecs.debug = true
          res = Amazon::Ecs.item_search(
            input, # キーワードを入力
            search_index: 'All', # 抜きたいジャンルを指定
            response_group: 'BrowseNodes',
            country: 'jp',
          )
          res = Amazon::Ecs.item_search(
            input, # キーワードを入力
            browse_node: res.items.first.get('BrowseNodes/BrowseNode/BrowseNodeId'),
            response_group: 'ItemAttributes',
            country: 'jp',
            sort: 'salesrank' # ソート順を売上順に指定することでランキングとする
          )
          i = 0
          ranks = res.items.map do |item|
            i += 1
            "＜#{i}位＞\n#{item.get('ItemAttributes/Title')}\n#{bitly_shorten(item.get('DetailPageURL'))}"
          end
          message = [{
            type: 'text',
            text: ranks[0]
          }]
          client.reply_message(event['replyToken'], message)
        end
      end
    end
    head :ok
  end

  private

  def client
    @client ||= Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET']
      config.channel_token = ENV['LINE_CHANNEL_TOKEN']
    end
  end

  def bitly_shorten(url)
    Bitly.use_api_version_3
    Bitly.configure do |config|
      config.api_version = 3
      config.access_token = ENV['BITLY_ACCESS_TOKEN']
    end
    Bitly.client.shorten(url).short_url
  end
end
