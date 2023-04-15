# frozen_string_literal: true

# Documentation: shut the fuck up
module FoodAlerts
  require 'dotenv/load'
  require 'json'

  # @twitter = Twitter::REST::Client.new do |config|
  #   config.consumer_key = ENV['TWITTER_CONSUMER_KEY']
  #   config.consumer_secret = ENV['TWITTER_CONSUMER_SECRET']
  #   config.access_token = ENV['TWITTER_ACCESS_TOKEN']
  #   config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
  # end

  class << self; attr_accessor :twitter; end

  class API
    require 'httpclient'
    require 'json'
    require 'time'

    def initialize
      @base_url = 'https://data.food.gov.uk/food-alerts'
      @client = HTTPClient.new(nil, 'FoodAlertsBot/0.1', nil)
      login_url = 'https://bsky.social/xrpc/com.atproto.server.createSession'
      bsky_identifier = ENV['BSKY_IDENTIFIER']
      bsky_password = ENV['BSKY_PASSWORD']
      login_body = {
        identifier: bsky_identifier,
        password: bsky_password
      }
      puts login_body
      res = @client.post(
        login_url,
        login_body.to_json,
        'Content-Type' => 'application/json'
      )
      puts res.content
      @did = JSON.parse(res.content)['did']
      @handle = JSON.parse(res.content)['handle']
      @email = JSON.parse(res.content)['email']
      @access_jwt = JSON.parse(res.content)['accessJwt']
      @refresh_jwt = JSON.parse(res.content)['refreshJwt']
      puts @did
      puts @handle
      puts @email
      puts @access_jwt
      puts @refresh_jwt
    end

    # function for posting to bluesky
    def post(content)
      base_url = 'https://bsky.social/xrpc/com.atproto.repo.createRecord'
      cookies = {
        ajs_anonymous_id: @ajs_anonymous_id,
        ajs_user_id: @ajs_user_id
      }
      post_body = {
        collection: 'app.bsky.feed.post',
        repo: @did,
        record: {
          'text' => content.to_s,
          # createdAt must look like 2023-04-15T19:56:00.933Z
          'createdAt' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%S.%LZ').to_s,
          '$type' => 'app.bsky.feed.post'
        }
      }
      # Send the post with @access_jwt as the Authorization header
      res = @client.post(
        base_url,
        post_body.to_json,
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@access_jwt}",
        'Cookie' => cookies
      )
      # res = @client.post(base_url, post_body.to_json, 'Content-Type' => 'application/json', 'Cookie' => cookies)
      # res = @client.post(base_url, post_body.to_json, 'Content-Type' => 'application/json')
      puts res.content
    end

    def list(limit: 10)
      res = @client.get("#{@base_url}/id?_limit=#{limit}")
      JSON.parse(res.content)['items']
    end

    def list_since(date, limit: 10)
      # 2018-01-29T16:10:00Z
      date_iso = date.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
      res = @client.get("#{@base_url}/id?since=#{date_iso}&_limit=#{limit}")
      JSON.parse(res.content)['items']
    end
  end

  # @last_poll = Time.now
  @last_poll = Time.parse('2023-04-01')
  @api = FoodAlerts::API.new

  def self.check_for_new
    puts "[+] Fetching new items since #{@last_poll}"
    items = @api.list_since(@last_poll)
    puts "[+] Fetched #{items.size} new items"
    items.each do |item|
      title = item['title']
      url = item['alertURL']
      tweet = "#{title}\n#{url}"
      puts '[+] Tweeting'
      puts tweet
      @api.post(tweet)
      # FoodAlerts.twitter.update(tweet)
      # Sleep for half an hour in case there's a bunch that we want to space out
      # If for some reason there are a *ton*, I suppose we might never catch up
      # but that's pretty unlikely
      sleep(60 * 30)
    end
    @last_poll = Time.now
  end

  module Jobs
    require 'rufus-scheduler'
    require 'time'

    @scheduler = Rufus::Scheduler.new

    @scheduler.every '1h', first_at: Time.now + 10 do
      puts "[+] Job triggered at #{Time.now}"
      FoodAlerts.check_for_new
      puts "[+] Job completed at #{Time.now}"
    end

    class << self; attr_accessor :scheduler; end
  end
end
