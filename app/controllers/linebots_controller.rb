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
            urls << bitly_shorten(item.get('DetailPageURL'))
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
                          "text": "1位",
                          "wrap": true,
                          # "size": "xs",
                          "margin": "md",
                          "color": "#ff5551",
                          "flex": 0
                        },
                        {
                          "type": "text",
                          "text": titles[0],
                          "wrap": true,
                          "weight": "bold",
                          "size": "lg"
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
                              # "size": "lg",
                              "flex": 0
                            }
                          ]
                        }                      ]
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
                          "text": "2位",
                          "wrap": true,
                          # "size": "xs",
                          "margin": "md",
                          "color": "#ff5551",
                          "flex": 0
                        },{
                          "type": "text",
                          "text": titles[1],
                          "wrap": true,
                          "weight": "bold",
                          "size": "lg"
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
                              # "size": "lg",
                              "flex": 0
                            }
                          ]
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
                          "text": "3位",
                          "wrap": true,
                          # "size": "xs",
                          "margin": "md",
                          "color": "#ff5551",
                          "flex": 0
                        },
                        {
                          "type": "text",
                          "text": titles[2],
                          "wrap": true,
                          "weight": "bold",
                          "size": "lg"
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
                              # "size": "lg",
                              "flex": 0
                            }
                          ]
                        }                      ]
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

  def seach_and_create_messages(input)
    # デバックログを出力するために記述(動作には影響なし)
    Amazon::Ecs.debug = true
    # AmazonAPIの仕様上、ALLジャンルからのランキングの取得はできないので、
    # ALLジャンルで商品検索→最初に出力された商品のジャンルを取得し、
    # そのジャンル内でのランキングを再度取得する。
    # つまり、2度APIを利用する。
    res1 = Amazon::Ecs.item_search(
      input, # キーワード指定
      search_index: 'All', # 抜きたいジャンルを指定
      response_group: 'BrowseNodes', # 取得したいジャンルIDはBrowseNodesグループに含まれているのでここで指定する
      country: 'jp'
    )
    # ジャンルIDを取得する
    # Amazonの公式ドキュメント（https://images-na.ssl-images-amazon.com/images/G/09/associates/paapi/dg/index.html）に
    # 各要素、取得するために使用する親要素の一覧が掲載されています
    browse_node_no = res1.items.first.get('BrowseNodes/BrowseNode/BrowseNodeId')
    res2 = Amazon::Ecs.item_search(
      input,
      browse_node: browse_node_no, # 取得したジャンルID内でのランキングを取得する
      response_group: 'ItemAttributes, Images, Offers',
      country: 'jp',
      sort: 'salesrank' # ソート順を売上順に指定することでランキングとする
    )
    make_reply_content(res2)
  end

  def make_reply_content(res2)
    {
      "type": "flex",
      "altText": "This is a Flex Message",
      "contents":
      {
        "type": "carousel",
        "contents": [
          make_part(res2.items[0], 1),
          make_part(res2.items[1], 2),
          make_part(res2.items[2], 3)
        ]
      }
    }
  end

  def make_content(item, rank)
    title << item.get('ItemAttributes/Title')
    price << choice_price(item.get('ItemAttributes/ListPrice/FormattedPrice'), item.get('OfferSummary/LowestNewPrice/FormattedPrice'))
    url << bitly_shorten(item.get('DetailPageURL'))
    image << item.get('LargeImage/URL')
    {
      "type": "bubble",
      "hero": {
        "type": "image",
        "size": "full",
        "aspectRatio": "20:13",
        "aspectMode": "cover",
        "url": image
      },
      "body":
      {
        "type": "box",
        "layout": "vertical",
        "spacing": "sm",
        "contents": [
          {
            "type": "text",
            "text": "#{rank}位",
            "wrap": true,
            "margin": "md",
            "color": "#ff5551",
            "flex": 0
          },
          {
            "type": "text",
            "text": title,
            "wrap": true,
            "weight": "bold",
            "size": "lg"
          },
          {
            "type": "box",
            "layout": "baseline",
            "contents": [
              {
                "type": "text",
                "text": price,
                "wrap": true,
                "weight": "bold",
                "flex": 0
              }
            ]
          }                      ]
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
              "uri": url
            }
          }
        ]
      }
    }
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
