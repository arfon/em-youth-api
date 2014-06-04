require 'sinatra'
require 'instagram'
require 'mongo_mapper'
require 'active_support'
require 'twilio-ruby'

class User
  include MongoMapper::Document

  key :instagram_id, String
  key :access_token, String
  key :instagram_name, String
  key :phone_number, String
  key :status, String
  
  scope :green, :status => 'green'
  scope :orange, :status => 'orange'
  scope :red, :status => 'red'
  
  many :images
  
  def green!
    update_attributes(:status => "green")
  end
  
  def orange!
    update_attributes(:status => "orange")
  end
  
  def red!
    update_attributes(:status => "red")
  end
end

class Image
  include MongoMapper::Document
  
  key :data, Hash
  timestamps!
  
  belongs_to :user
end

# Configuration

configure do
  MongoMapper.setup({'production' => {'uri' => ENV['MONGOHQ_URL']}}, 'production')
end

Instagram.configure do |config|
  config.client_id = ENV['CLIENT_ID']
  config.client_secret = ENV['CLIENT_SECRET']
end

TWILIO_CLIENT = Twilio::REST::Client.new(ENV['TWILIO_SID'], ENV['TWILIO_TOKEN'])

enable :sessions

# OAuth stuff

CALLBACK_URL = "http://#{ENV['DOMAIN']}/oauth/callback"

get "/oauth/connect" do
  redirect Instagram.authorize_url(:redirect_uri => CALLBACK_URL)
end

get '/oauth/callback' do
  response = Instagram.get_access_token(params[:code], :redirect_uri => CALLBACK_URL)
  session[:access_token] = response.access_token
  user = Instagram.client(:access_token => response.access_token).user
  User.first_or_create(:access_token => session[:access_token], :instagram_id => user.id, :instagram_name => user.username)
  redirect "/hello"
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
  erb :index
end

get '/hello' do
  'Boo ya!'
end

get '/status/?:user_id?' do
  if params[:user_id]
    user = User.find_by_instagram_id(params[:user_id])
    erb :user, :locals => { :user => user }
  else
    erb :status, :locals => { :green => User.green, :orange => User.orange, :red => User.red }
  end
end

# Verifies subscription (http://instagram.com/developer/realtime/)
get '/callback' do
  request['hub.challenge'] if request['hub.verify_token'] == ENV['HUB_TOKEN']
end

# Receive subscription (http://instagram.com/developer/realtime/)
post '/callback' do
  begin
    process_subscription(request.body.read, env['HTTP_X_HUB_SIGNATURE'])
  rescue Instagram::InvalidSignature
    halt 403
  end
end

# Do magic...
def process_subscription(body, signature)
  fail Instagram::InvalidSignature unless signature

  Instagram.process_subscription(body, signature: signature) do |handler|
    handler.on_user_changed do |user_id, data|
      user = User.find_by_instagram_id(user_id)
      @client = Instagram.client(:access_token => user.access_token)
      text = @client.user_recent_media[0]
      user.images.create(:data => text)
      user.green!
      TWILIO_CLIENT.account.messages.create(
        :from => ENV['TWILIO_FROM'],
        :to => user.phone_number,
        :body => "Thanks for checking in!"
      )
    end
  end
end
