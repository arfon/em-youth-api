require 'instagram'
require './web.rb'

task :configure do
  Instagram.configure do |config|
    config.client_id = ENV['CLIENT_ID']
    config.client_secret = ENV['CLIENT_SECRET']
  end
end

desc 'List all subscriptions'
task subs: :configure do
  Instagram.subscriptions.each { |sub| p sub }
end

desc 'Create a Instagram tag subscription'
task create_sub: :configure do
  Instagram.create_subscription(
    'user',
    "http://#{ENV['DOMAIN']}/callback",
    verify_token: ENV['HUB_TOKEN'])
  puts "User subscription created!"
end

desc 'Delete Users'
task :delete_users_and_images do
  User.destroy_all
  Image.destroy_all
end