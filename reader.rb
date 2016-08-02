require 'rubygems'
require 'sinatra/base'
require 'mongoid'
require 'feedjira'

class Reader < Sinatra::Base
  Mongoid.load!('mongo.yml')

  class Feed
    include Mongoid::Document
  
    field :url, type: String
    field :title, type: String
    field :hit_count, type: Integer, default: 0
    has_and_belongs_to_many :tags
  end

  class Tag
    include Mongoid::Document

    field :name, type: String
    has_and_belongs_to_many :feeds
  end

  helpers do
    def protected!
      return if authorized?
      headers['WWW-Authenticate'] = 'Basic realm="Restricted Area"'
      halt 401, "Not authorized\n"
    end

    def authorized?
      @auth ||= Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? and @auth.basic? and @auth.credentials and @auth.credentials == [ENV['CLOUD_USER'], ENV['CLOUD_PASS']]
    end
  end

  get "/" do
    # _id should be a timestamp so sorting on it sorts by creation time
    @recent_feeds = Feed.desc(:_id).limit(5)
    @popular_feeds = Feed.desc(:hit_count).limit(15)
    @tags = Tag.asc(:name)

    erb :welcome
  end

  get "/feeds" do 
    @feeds = Feed.all
    @tags = Tag.asc(:name)

    erb :index
  end

  post "/feeds/new" do 
    protected!

    url = params[:url]
    feed_tags = params[:tags]
    rss = Feedjira::Feed.fetch_and_parse(url)
    feed = Feed.new

    feed.title = rss.title
    feed.url = url
    feed.hit_count = 0
    feed.save

    feed_tags.split.each do |tagname|
      tag = Tag.find_or_create_by(name: tagname) 
      feed.tags.push(tag)
    end

    redirect '/'
  end

  get "/feeds/show/:id" do |id|
    @feed = Feed.find(id)
    @feed.hit_count = @feed.hit_count + 1
    @feed.save

    rss = Feedjira::Feed.fetch_and_parse(@feed.url)
    rss.sanitize_entries!
    @entries = rss.entries
    
    erb :show
  end

  get "/feeds/edit/:id" do |id|
    @feed = Feed.find(id)

    erb :edit
  end

  post "/feeds/update" do
    protected!

    id = params[:id]
    feed = Feed.find(id)
    feed.tags.clear
    feed_tags = params[:tags].split
    feed_tags.each do |tagname|
      tag = Tag.find_or_create_by(name: tagname) 
      feed.tags.push(tag)
    end
    
    redirect '/show/' + id
  end

  get "/feeds/delete/:id" do |id|
    protected!

    @feed = Feed.find(id)
    @feed.delete

    redirect '/'
  end

  get "/feeds/tags/:name" do |name|
    @feeds = Tag.find_by(name: name).feeds
    @tags = Tag.asc(:name)

    erb :index
  end
end
