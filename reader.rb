require 'rubygems'
require 'sinatra/base'
require 'mongoid'
require 'feedzirra'

class Reader < Sinatra::Base
	Mongoid.load!('mongo.yml')

	class Feed
	  include Mongoid::Document
  
	  field :url, type: String
	  field :title, type: String
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
	  @feeds = Feed.all
    @tag_names = Tag.all.pluck(:name)

	  erb :index
	end

	post "/new" do 
    protected!

	  url = params[:url]
    feed_tags = params[:tags]
    rss = Feedzirra::Feed.fetch_and_parse(url)
    feed = Feed.new

    feed.title = rss.title
    feed.url = url
	  feed.save

    feed_tags.split.each do |tagname|
      tag = Tag.find_or_create_by(name: tagname) 
      feed.tags.push(tag)
    end

    redirect '/'
	end

	get "/show/:id" do |id|
	  @feed = Feed.find(id)

    rss = Feedzirra::Feed.fetch_and_parse(@feed.url)
    rss.sanitize_entries!
    @entries = rss.entries
	  
	  erb :show
	end

  get "/edit/:id" do |id|
    @feed = Feed.find(id)

    erb :edit
  end

  post "/update" do
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

	get "/delete/:id" do |id|
    protected!

	  @feed = Feed.find(id)
	  @feed.delete

	  redirect '/'
	end

  get "/tags/:name" do |name|
    @feeds = Tag.find_by(name: name).feeds
    @tag_names = Tag.all.pluck(:name)

    erb :index
  end
end
