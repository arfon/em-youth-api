require 'sinatra'
require 'instagram'
require 'mongo_mapper'
require 'active_support'
require 'twilio-ruby'

enable :sessions

TWILIO_CLIENT = Twilio::REST::Client.new(ENV['TWILIO_SID'], ENV['TWILIO_TOKEN'])

class User
  include MongoMapper::Document

  key :instagram_id, String
  key :access_token, String
  key :instagram_name, String
  key :phone_number, String

  many :images
end

class Image
  include MongoMapper::Document
  
  key :data, Hash
  timestamps!
  
  belongs_to :user
end

configure do
  MongoMapper.setup({'production' => {'uri' => ENV['MONGOHQ_URL']}}, 'production')
end

CALLBACK_URL = "http://#{ENV['DOMAIN']}/oauth/callback"

Instagram.configure do |config|
  config.client_id = ENV['CLIENT_ID']
  config.client_secret = ENV['CLIENT_SECRET']
end

def process_sub(req_body, signature)
  fail Instagram::InvalidSignature unless signature

  Instagram.process_subscription(req_body, signature: signature) do |handler|
    handler.on_user_changed do |user_id, data|
      user = User.find_by_instagram_id(user_id)
      @client = Instagram.client(:access_token => user.access_token)
      text = @client.user_recent_media[0]
      user.images.create(:data => text)
      TWILIO_CLIENT.account.messages.create(
        :from => ENV['TWILIO_FROM'],
        :to => user.phone_number,
        :body => "Thanks for checking in!"
      )
    end
  end
end

get '/activity' do
  users = User.all
  response = []

  users.each do |user|
    next unless user.images.any?
    
    if user.images.last.created_at < 2.hours.ago
      status = "red"
    elsif user.images.last.created_at < 1.hour.ago
      status = "orange"
    else
      status = "green"
    end
    
    response << { :username => user.instagram_name, 
                  :image => user.images.last[:data][:images], 
                  :location => user.images.last[:data][:location],
                  :phone_number => user.phone_number,
                  :status => status }
  end
  response.to_json
end

get '/' do
  '<a href="/oauth/connect">Connect with Instagram</a>'
end

get "/oauth/connect" do
  redirect Instagram.authorize_url(:redirect_uri => CALLBACK_URL)
end

get '/oauth/callback' do
  response = Instagram.get_access_token(params[:code], :redirect_uri => CALLBACK_URL)
  session[:access_token] = response.access_token
  user = Instagram.client(:access_token => response.access_token).user
  User.first_or_create(:access_token => session[:access_token], :instagram_id => user.id, :instagram_name => user.username)
  redirect "/nav"
end

get "/nav" do
  html =
  """
    <h1>Ruby Instagram Gem Sample Application</h1>
    <ol>
      <li><a href='/user_recent_media'>User Recent Media</a> Calls user_recent_media - Get a list of a user's most recent media</li>
      <li><a href='/user_media_feed'>User Media Feed</a> Calls user_media_feed - Get the currently authenticated user's media feed uses pagination</li>
      <li><a href='/location_recent_media'>Location Recent Media</a> Calls location_recent_media - Get a list of recent media at a given location, in this case, the Instagram office</li>
      <li><a href='/media_search'>Media Search</a> Calls media_search - Get a list of media close to a given latitude and longitude</li>
      <li><a href='/media_popular'>Popular Media</a> Calls media_popular - Get a list of the overall most popular media items</li>
      <li><a href='/user_search'>User Search</a> Calls user_search - Search for users on instagram, by name or username</li>
      <li><a href='/location_search'>Location Search</a> Calls location_search - Search for a location by lat/lng</li>
      <li><a href='/location_search_4square'>Location Search - 4Square</a> Calls location_search - Search for a location by Fousquare ID (v2)</li>
      <li><a href='/tags'>Tags</a>Search for tags, view tag info and get media by tag</li>
      <li><a href='/limits'>View Rate Limit and Remaining API calls</a>View remaining and ratelimit info.</li>
    </ol>
  """
  html
end

get '/callback' do
  request['hub.challenge'] if request['hub.verify_token'] == ENV['HUB_TOKEN']
end

post '/callback' do
  begin
    process_sub(request.body.read, env['HTTP_X_HUB_SIGNATURE'])
  rescue Instagram::InvalidSignature
    halt 403
  end
  'Gocha!'
end
