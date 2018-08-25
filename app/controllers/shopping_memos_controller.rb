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
          when /.*amazon|Amazon|アマゾン.*/
            user = User.find_or_create_by(line_id: line_id)
            if user.amazon
              message = {
                type: 'text',
                text: "検索対象はAmazonになっているよ！\n楽天に切り替えたいときは「楽天」と送信してね"
              }
            else
              user.update!(amazon: true)
              message = {
                type: 'text',
                text: "検索対象をAmazonに切り替えたよ！\n楽天に戻したいときは「楽天」と送信してね"
              }
            end
          when /.*楽天|rakuten|Rakuten.*/
            user = User.find_or_create_by(line_id: line_id)
            if user.amazon
              user.update!(amazon: false)
              message = {
                type: 'text',
                text: "検索対象を楽天に切り替えたよ！\nAmazonに戻したいときは「Amazon」と送信してね"
              }
            else
              message = {
                type: 'text',
                text: "検索対象は楽天になっているよ！\nAmazonに切り替えたいときは「Amazon」と送信してね"
              }
            end
          when /リスト/
            things = ShoppingMemo.where(line_id: line_id, alive: true).pluck(:thing)
            message = if things.present?
                        amazon = User.find_or_create_by(line_id: line_id).amazon
                        create_message(things, amazon)
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
              text: "クリアしたよー！\nお買い物お疲れさま！"
            }
          else
            ShoppingMemo.create(thing: input, line_id: line_id)
            message = {
              type: 'text',
              text: ['OK!', 'Yeah!', 'おけ', 'りょ', 'Yes!', 'Good!', 'Nice!', 'Great!', 'Perfect!'].sample,
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

  def create_message(things, amazon)
    # デバックログ出力するために記述
    Amazon::Ecs.debug = true if amazon
    [
      {
        "type": 'flex',
        "altText": 'This is a Flex Message',
        "contents":
        {
          "type": 'carousel',
          "contents":
          create_contents(things, amazon)
        }
      },
      {
        type: 'text',
        text: list(things)
      }
    ]
  end

  def list(things)
    contents = "＜お買い物リスト＞\n1：#{things.shift}"
    things.each_with_index do |thing, i|
      contents += "\n#{i + 2}：#{thing}"
    end
    contents
  end

  def create_contents(things, amazon)
    contents = ''
    case things.size
    when 1
      contents = [create_content(things[0], amazon)]
    when 2
      contents = create_content(things[0], amazon), create_content(things[1], amazon)
    when 3
      contents = create_content(things[0], amazon), create_content(things[1], amazon), create_content(things[2], amazon)
    when 4
      contents = create_content(things[0], amazon), create_content(things[1], amazon), create_content(things[2], amazon), create_content(things[3], amazon)
    when 5
      contents = create_content(things[0], amazon), create_content(things[1], amazon), create_content(things[2], amazon), create_content(things[3], amazon), create_content(things[4], amazon)
    when 6
      contents = create_content(things[0], amazon), create_content(things[1], amazon), create_content(things[2], amazon), create_content(things[3], amazon), create_content(things[4], amazon), create_content(things[5], amazon)
    when 7
      contents = create_content(things[0], amazon), create_content(things[1], amazon), create_content(things[2], amazon), create_content(things[3], amazon), create_content(things[4], amazon), create_content(things[5], amazon), create_content(things[6], amazon)
    when 8
      contents = create_content(things[0], amazon), create_content(things[1], amazon), create_content(things[2], amazon), create_content(things[3], amazon), create_content(things[4], amazon), create_content(things[5], amazon), create_content(things[6], amazon), create_content(things[7], amazon)
    when 9
      contents = create_content(things[0], amazon), create_content(things[1], amazon), create_content(things[2], amazon), create_content(things[3], amazon), create_content(things[4], amazon), create_content(things[5], amazon), create_content(things[6], amazon), create_content(things[7], amazon), create_content(things[8], amazon)
    else
      contents = create_content(things[0], amazon), create_content(things[1], amazon), create_content(things[2], amazon), create_content(things[3], amazon), create_content(things[4], amazon), create_content(things[5], amazon), create_content(things[6], amazon), create_content(things[7], amazon), create_content(things[8], amazon), create_content(things[9], amazon)
    end
    contents
  end

  def create_content(thing, amazon)
    if amazon
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
      amazon_or_rakuten = 'Amazon'
    else
      RakutenWebService.configuration do |c|
        c.application_id = ENV['RAKUTEN_APPID']
        c.affiliate_id = ENV['RAKUTEN_AFID']
      end
      item0 = RakutenWebService::Ichiba::Item.search(keyword: thing, hits: 1, imageFlag: 1).first

      genre_id = item0['genreId']
      item = RakutenWebService::Ichiba::Item.ranking(genreId: genre_id).first

      title = item['itemName']
      price = item['itemPrice'].to_s
      url = item['itemUrl']
      image = item['mediumImageUrls'].first
      amazon_or_rakuten = '楽天'
    end
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
            "text": "「#{thing}」#{amazon_or_rakuten} 1位",
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
              "label": "#{amazon_or_rakuten}商品ページへ",
              "uri": url
            }
          }
        ]
      }
    }
  end
end
