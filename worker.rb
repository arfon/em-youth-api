require './web.rb'

# FIXME - work out how to do these dates properly

START_TIME = Time.parse('1pm').utc
END_TIME = Time.parse('1am').utc + 1.day

if Time.now.between?(START_TIME, END_TIME)  
  User.all.each do |user|
    next unless user.images.any?
    if user.images.last.created_at < 2.hours.ago
      TWILIO_CLIENT.account.messages.create(
        :from => ENV['TWILIO_FROM'],
        :to => user.phone_number,
        :body => "Hey, it's been two hours since you last checked in. Calling your supervisor..."
      )
    elsif user.images.last.created_at < 1.hour.ago
      TWILIO_CLIENT.account.messages.create(
        :from => ENV['TWILIO_FROM'],
        :to => user.phone_number,
        :body => "Hey, it's been an hour since you last checked in. Please check in again."
      )
    end
  end
end