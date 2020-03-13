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
          # 入力した文字をinputに格納
          input = event.message['text']
          # search_and_create_messageメソッド内で、AmazonAPIを用いた商品検索、メッセージの作成を行う
          messages = search_and_create_messages(input)
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

  def request
    @request ||= Vacuum.new(marketplace: 'JP',
                            access_key: ENV['AMAZON_API_ACCESS_KEY'],
                            secret_key: ENV['AMAZON_API_SECRET_KEY'],
                            partner_tag: ENV['ASSOCIATE_TAG'])
  end

  def search_and_create_messages(keyword)
    # AmazonAPIの仕様上、ALLジャンルからのランキングの取得はできないので、
    # ALLジャンルで商品検索→最初に出力された商品のジャンルを取得し、
    # そのジャンル内でのランキングを再度取得する。
    # つまり、2度APIを利用する

    # ジャンルIDを取得する
    res1 = request.search_items(keywords: keyword,
                                resources: ['BrowseNodeInfo.BrowseNodes']).to_h
    browse_node_no = res1.dig('SearchResult','Items').first.dig('BrowseNodeInfo','BrowseNodes').first.dig('Id')

    # ジャンルÎD内でのランキングを取得する
    # ジャンルIDを指定するとデフォルトで売上順になる（↓に記載）
    # https://docs.aws.amazon.com/AWSECommerceService/latest/DG/APPNDX_SortValuesArticle.html
    res2 = request.search_items(keywords: keyword,
                                browse_node_id: browse_node_no, resources:
                                ['ItemInfo.Title', 'Images.Primary.Large', 'Offers.Listings.Price']).to_h
    items = res2.dig('SearchResult', 'Items')

    make_reply_content(items)
  end
  # LINE公式のFlex Message Simulator(https://developers.line.me/console/fx/)でShoppingのテーマをベースに作成
  # 細かい仕様はLINE公式ドキュメント(https://developers.line.me/ja/docs/messaging-api/using-flex-messages/)ご参照
  def make_reply_content(items)
    {
      "type": "flex",
      "altText": "This is a Flex Message",
      "contents":
      {
        "type": "carousel",
        "contents": [
          make_part(items[0], 1),
          make_part(items[1], 2),
          make_part(items[2], 3)
        ]
      }
    }
  end

  def make_part(item, rank)
    title = item.dig('ItemInfo', 'Title', 'DisplayValue')
    price = item.dig('Offers', 'Listings').first.dig('Price', 'DisplayAmount')
    url = item.dig('DetailPageURL')
    image = item.dig('Images', 'Primary', 'Large', 'URL')
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
          }]
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
end
