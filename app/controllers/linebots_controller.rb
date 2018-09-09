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

  def search_and_create_messages(input)
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
    # 各要素、取得するために使用する親要素の一覧が掲載されている
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
  # LINE公式のFlex Message Simulator(https://developers.line.me/console/fx/)でShoppingのテーマをベースに作成
  # 細かい使用はLINE公式ドキュメント(https://developers.line.me/ja/docs/messaging-api/using-flex-messages/)ご参照
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

  def make_part(item, rank)
    title = item.get('ItemAttributes/Title')
    # 価格は2箇所から取得しており、1番目の方にデータがない場合2番目のデータを使う
    price = item.get('ItemAttributes/ListPrice/FormattedPrice') || item.get('OfferSummary/LowestNewPrice/FormattedPrice')
    url = bitly_shorten(item.get('DetailPageURL'))
    image = item.get('LargeImage/URL')
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
end
