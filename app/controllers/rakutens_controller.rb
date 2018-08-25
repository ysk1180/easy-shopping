class RakutensController < ApplicationController
  require 'line/bot'

  # callbackアクションのCSRFトークン認証を無効
  protect_from_forgery except: [:callback]

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
          message = create_message(input)
          client.reply_message(event['replyToken'], message)
        end
      end
    end
    head :ok
  end

  private

  def client
    @client ||= Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET_RAKUTEN']
      config.channel_token = ENV['LINE_CHANNEL_TOKEN_RAKUTEN']
    end
  end

  def create_message(input)
    # デバックログ出力するために記述
    {
      "type": 'flex',
      "altText": 'This is a Flex Message',
      "contents":
      {
        "type": 'carousel',
        "contents":
        create_content(input)
      }
    }
  end

  def create_content(input)
    RakutenWebService.configuration do |c|
      c.application_id = ENV['RAKUTEN_APPID']
      c.affiliate_id = ENV['RAKUTEN_AFID']
    end
    item0 = RakutenWebService::Ichiba::Item.search(keyword: input, hits: 1, imageFlag: 1).first

    genre_id = item0['genreId']
    item = RakutenWebService::Ichiba::Item.ranking(genreId: genre_id).first

    title = item['itemName']
    price = item['itemPrice'].to_s
    url = item['itemUrl']
    image = item['mediumImageUrls'].first

    # browse_node_no = res1.items.first.get('BrowseNodes/BrowseNode/BrowseNodeId')
    # res2 = Amazon::Ecs.item_search(
    #   thing,
    #   browse_node: browse_node_no,
    #   response_group: 'ItemAttributes, Images, Offers',
    #   country: 'jp',
    #   sort: 'salesrank' # ソート順を売上順に指定することでランキングとする
    # )
    # item = res2.items.first
    # title = item.get('ItemAttributes/Title')
    # price = choice_price(item.get('ItemAttributes/ListPrice/FormattedPrice'), item.get('OfferSummary/LowestNewPrice/FormattedPrice'))
    # url = bitly_shorten(item.get('DetailPageURL'))
    # image = item.get('LargeImage/URL')
    [
    {
      "type": 'bubble',
      "hero": {
        "type": 'image',
        "size": 'full',
        "aspectRatio": '20:13',
        "aspectMode": 'cover',
        "url": image
      },
      "body":
      {
        "type": 'box',
        "layout": 'vertical',
        "spacing": 'sm',
        "contents": [
          {
            "type": 'text',
            "text": "「#{input}」Amazon 1位",
            "wrap": true,
            # "size": "xs",
            "margin": 'md',
            "color": '#ff5551',
            "flex": 0
          },
          {
            "type": 'text',
            "text": title,
            "wrap": true,
            "weight": 'bold',
            "size": 'lg'
          },
          {
            "type": 'box',
            "layout": 'baseline',
            "contents": [
              {
                "type": 'text',
                "text": price,
                "wrap": true,
                "weight": 'bold',
                # "size": "lg",
                "flex": 0
              }
            ]
          }
        ]
      },
      "footer": {
        "type": 'box',
        "layout": 'vertical',
        "spacing": 'sm',
        "contents": [
          {
            "type": 'button',
            "style": 'primary',
            "action": {
              "type": 'uri',
              "label": 'Amazon商品ページへ',
              "uri": url
            }
          }
        ]
      }
    }
    ]
  end
end
