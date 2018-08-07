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
          res1 = Amazon::Ecs.item_search(
            input, # キーワード指定
            search_index: 'All', # 抜きたいジャンルを指定
            response_group: 'BrowseNodes',
            country: 'jp'
          )
          browse_node_no = res1.items.first.get('BrowseNodes/BrowseNode/BrowseNodeId')
          res2 = Amazon::Ecs.item_search(
            input,
            browse_node: browse_node_no,
            response_group: 'ItemAttributes, Images, Offers',
            country: 'jp',
            sort: 'salesrank' # ソート順を売上順に指定することでランキングとする
          )
          titles = []
          images = []
          prices = []
          urls = []
          res2.items.each.with_index(1) do |item, i|
            # titles << "＜#{i}位＞\n#{item.get('ItemAttributes/Title')}\n#{choice_price(item.get('ItemAttributes/ListPrice/FormattedPrice'), item.get('OfferSummary/LowestNewPrice/FormattedPrice'))}\n#{bitly_shorten(item.get('DetailPageURL'))}"

            titles << item.get('ItemAttributes/Title')
            prices << choice_price(item.get('ItemAttributes/ListPrice/FormattedPrice'), item.get('OfferSummary/LowestNewPrice/FormattedPrice'))
            urls << item.get('DetailPageURL')
            images << item.get('LargeImage/URL')

            break if i == 3
          end
          messages = 
            # [
            {
              "type": "flex",
              "altText": "This is a Flex Message",
              "contents": 
              {
                "type": "carousel",
                "contents": [
                  {
                    "type": "bubble",
                    "hero": {
                      "type": "image",
                      "size": "full",
                      "aspectRatio": "20:13",
                      "aspectMode": "cover",
                      "url": images[0]
                    },
                    "body":
                    {
                      "type": "box",
                      "layout": "vertical",
                      "spacing": "sm",
                      "contents": [
                        {
                          "type": "text",
                          "text": titles[0],
                          "wrap": true,
                          "weight": "bold",
                          "size": "xl"
                        },
                        {
                          "type": "box",
                          "layout": "baseline",
                          "contents": [
                            {
                              "type": "text",
                              "text": prices[0],
                              "wrap": true,
                              "weight": "bold",
                              "size": "xl",
                              "flex": 0
                            }
                          ]
                        },{
                          "type": "text",
                          "text": "1位",
                          "wrap": true,
                          "size": "xs",
                          "margin": "md",
                          "color": "#ff5551",
                          "flex": 0
                        }
                      ]
                    },
                    "footer": {
                      "type": "box",
                      "layout": "vertical",
                      "spacing": "sm",
                      "contents": [
                        {
                          "type": "button",
                          "style": "primary",
                          "action": {
                            "type": "uri",
                            "label": "Amazon商品ページへ",
                            "uri": urls[0]
                          }
                        }
                      ]
                    }
                  },
                  {
                    "type": "bubble",
                    "hero": {
                      "type": "image",
                      "size": "full",
                      "aspectRatio": "20:13",
                      "aspectMode": "cover",
                      "url": images[1]
                    },
                    "body":
                    {
                      "type": "box",
                      "layout": "vertical",
                      "spacing": "sm",
                      "contents": [
                        {
                          "type": "text",
                          "text": titles[1],
                          "wrap": true,
                          "weight": "bold",
                          "size": "xl"
                        },
                        {
                          "type": "box",
                          "layout": "baseline",
                          "contents": [
                            {
                              "type": "text",
                              "text": prices[1],
                              "wrap": true,
                              "weight": "bold",
                              "size": "xl",
                              "flex": 0
                            }
                          ]
                        },{
                          "type": "text",
                          "text": "2位",
                          "wrap": true,
                          "size": "xs",
                          "margin": "md",
                          "color": "#ff5551",
                          "flex": 0
                        }
                      ]
                    },
                    "footer": {
                      "type": "box",
                      "layout": "vertical",
                      "spacing": "sm",
                      "contents": [
                        {
                          "type": "button",
                          "style": "primary",
                          "action": {
                            "type": "uri",
                            "label": "Amazon商品ページへ",
                            "uri": urls[1]
                          }
                        }
                      ]
                    }
                  },
                  {
                    "type": "bubble",
                    "hero": {
                      "type": "image",
                      "size": "full",
                      "aspectRatio": "20:13",
                      "aspectMode": "cover",
                      "url": images[2]
                    },
                    "body":
                    {
                      "type": "box",
                      "layout": "vertical",
                      "spacing": "sm",
                      "contents": [
                        {
                          "type": "text",
                          "text": titles[2],
                          "wrap": true,
                          "weight": "bold",
                          "size": "xl"
                        },
                        {
                          "type": "box",
                          "layout": "baseline",
                          "contents": [
                            {
                              "type": "text",
                              "text": prices[2],
                              "wrap": true,
                              "weight": "bold",
                              "size": "xl",
                              "flex": 0
                            }
                          ]
                        },{
                          "type": "text",
                          "text": "3位",
                          "wrap": true,
                          "size": "xs",
                          "margin": "md",
                          "color": "#ff5551",
                          "flex": 0
                        }
                      ]
                    },
                    "footer": {
                      "type": "box",
                      "layout": "vertical",
                      "spacing": "sm",
                      "contents": [
                        {
                          "type": "button",
                          "style": "primary",
                          "action": {
                            "type": "uri",
                            "label": "Amazon商品ページへ",
                            "uri": urls[2]
                          }
                        }
                      ]
                    }
                  }
                ]
              }
          }

          #     {
          #     type: 'text',
          #     text: titles[0]
          #   }, {
          #     type: 'image',
          #     originalContentUrl: images[0],
          #     previewImageUrl: images[0]
          #   }, {
          #     type: 'text',
          #     text: titles[1]
          #   }, {
          #     type: 'image',
          #     originalContentUrl: images[1],
          #     previewImageUrl: images[1]
          #   }, {
          #     type: 'text',
          #     text: titles[2]
          #   }
          # ]
          client.reply_message(event['replyToken'], messages)
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

  def choice_price(amazon_price, other_price)
    amazon_price.present? ? amazon_price : other_price
  end
end
