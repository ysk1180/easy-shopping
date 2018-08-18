# frozen_string_literal: true

class ShoppingMemosController < ApplicationController
  require 'line/bot'
  require 'bitly'

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
          line_id = event['source']['userId']
          case input
          when /リスト/
            things = ShoppingMemo.where(line_id: line_id, alive: true).pluck(:thing)
            message = if things.present?
                        create_message(things)
                      else
                        {
                          type: 'text',
                          text: '買うものはないよ〜'
                        }
                      end
          when /クリア/
            ShoppingMemo.where(line_id: line_id, alive: true).update_all(alive: false)
            message = {
              type: 'text',
              text: 'クリアしたよ!'
            }
          else
            ShoppingMemo.create(thing: input, line_id: line_id)
            message = {
              type: 'text',
              text: 'OK!',
              "quickReply": {
                "items": [
                  {
                    "type": 'action',
                    # "imageUrl": "https://example.com/tempura.png",
                    "action": {
                      "type": 'message',
                      "label": 'リスト（一覧表示）',
                      "text": 'リスト'
                    }
                  },
                  {
                    "type": 'action',
                    # "imageUrl": "https://example.com/tempura.png",
                    "action": {
                      "type": 'message',
                      "label": 'クリア（すべて消去）',
                      "text": 'クリア'
                    }
                  }
                ]
              }
            }
          end
          client.reply_message(event['replyToken'], message)
        end
      end
    end
    head :ok
  end

  private

  def client
    @client ||= Line::Bot::Client.new do |config|
      config.channel_secret = ENV['LINE_CHANNEL_SECRET_MEMO']
      config.channel_token = ENV['LINE_CHANNEL_TOKEN_MEMO']
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

  def create_message(things)
    # デバックログ出力するために記述
    Amazon::Ecs.debug = true
    # t = things
    {
      "type": 'flex',
      "altText": 'This is a Flex Message',
      "contents":
      {
        "type": 'carousel',
        "contents":
        create_contents(things)
      }
    }
  end

  def create_contents(things)
    contents = ''
    case things.size
    when 1
      contents = [create_content(things[0])]
    when 2
      contents = create_content(things[0]), create_content(things[1])
    when 3
      contents = create_content(things[0]), create_content(things[1]), create_content(things[2])
    when 4
      contents = create_content(things[0]), create_content(things[1]), create_content(things[2]), create_content(things[3])
    when 5
      contents = create_content(things[0]), create_content(things[1]), create_content(things[2]), create_content(things[3]), create_content(things[4])
    when 6
      contents = create_content(things[0]), create_content(things[1]), create_content(things[2]), create_content(things[3]), create_content(things[4]), create_content(things[5])
    when 7
      contents = create_content(things[0]), create_content(things[1]), create_content(things[2]), create_content(things[3]), create_content(things[4]), create_content(things[5]), create_content(things[6])
    when 8
      contents = create_content(things[0]), create_content(things[1]), create_content(things[2]), create_content(things[3]), create_content(things[4]), create_content(things[5]), create_content(things[6]), create_content(things[7])
    when 9
      contents = create_content(things[0]), create_content(things[1]), create_content(things[2]), create_content(things[3]), create_content(things[4]), create_content(things[5]), create_content(things[6]), create_content(things[7]), create_content(things[8])
    else
      contents = create_content(things[0]), create_content(things[1]), create_content(things[2]), create_content(things[3]), create_content(things[4]), create_content(things[5]), create_content(things[6]), create_content(things[7]), create_content(things[8]), create_content(things[9])
    end
    contents
  end

  def create_content(thing)
    res1 = Amazon::Ecs.item_search(
      thing, # キーワード指定
      search_index: 'All', # 抜きたいジャンルを指定
      response_group: 'BrowseNodes',
      country: 'jp'
    )
    browse_node_no = res1.items.first.get('BrowseNodes/BrowseNode/BrowseNodeId')
    res2 = Amazon::Ecs.item_search(
      thing,
      browse_node: browse_node_no,
      response_group: 'ItemAttributes, Images, Offers',
      country: 'jp',
      sort: 'salesrank' # ソート順を売上順に指定することでランキングとする
    )
    item = res2.items.first
    title = item.get('ItemAttributes/Title')
    price = choice_price(item.get('ItemAttributes/ListPrice/FormattedPrice'), item.get('OfferSummary/LowestNewPrice/FormattedPrice'))
    url = bitly_shorten(item.get('DetailPageURL'))
    image = item.get('LargeImage/URL')
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
            "text": "「#{thing}」Amazon1位",
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
  end
end
