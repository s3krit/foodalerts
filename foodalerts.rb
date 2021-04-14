# frozen_string_literal: true

module FoodAlerts
  require 'twitter'

  @twitter = Twitter::REST::Client.new do |config|
    config.consumer_key = ENV['TWITTER_CONSUMER_KEY']
    config.consumer_secret = ENV['TWITTER_CONSUMER_SECRET']
    config.access_token = ENV['TWITTER_ACCESS_TOKEN']
    config.access_token_secret = ENV['TWITTER_ACCESS_TOKEN_SECRET']
  end

  class << self; attr_accessor :twitter; end

  class API
    require 'httpclient'
    require 'json'
    require 'time'

    def initialize
      @base_url = 'https://data.food.gov.uk/food-alerts'
      @client = HTTPClient.new(nil, 'FoodAlertsBot/0.1', nil)
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

  @last_poll = Time.parse('2021-04-13')
  @api = FoodAlerts::API.new

  def self.check_for_new
    puts "[+] Fetching new items since #{@last_poll}"
    items = @api.list_since(@last_poll)
    puts "[+] Fetched #{items.size} new items"
    items.each do |item|
      title = item['title']
      url = item['alertURL']
      tweet = "#{title}\n#{url}"
      puts tweet
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

    @scheduler.every '1h' do
      FoodAlerts.check_for_new
    end

    class << self; attr_accessor :scheduler; end
  end
end
