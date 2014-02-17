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
	end

	get "/" do 
	  @feeds = Feed.all

	  erb :index
	end

	post "/new" do 
	  url = params[:url]
    rss = Feedzirra::Feed.fetch_and_parse(url)
    feed = Feed.new

    feed.title = rss.title
    feed.url = url

	  feed.save
	  redirect '/'
	end

	get "/show/:id" do |id|
	  @feed = Feed.find(id)
	  @entries = []

    rss = Feedzirra::Feed.fetch_and_parse(@feed.url)
    rss.entries.each do |entry|
      @entries.push(entry)
    end
	  
	  erb :show
	end

	get "/delete/:id" do |id|
	  @feed = Feed.find(id)
	  @feed.delete

	  redirect '/'
	end
end
