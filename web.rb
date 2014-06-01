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
  redirect "/hello"
end

get "/hello" do
  "Boo ya!"
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
end
