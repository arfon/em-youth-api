Grounded
======

Built as part of the [Adler Planetarium's](http://www.adlerplanetarium.org/) [Civic Hack Day](http://civichack.adlerplanetarium.org/2014/) on 31 May 2014. This is a simple application that monitors the Instagram API for updates from a group of users (who have authorised the application to receive updates from their account) and then makes this information available to others.

## Why does this exist?

Because ankle bracelets are embarrassing, demoralising and often more than is required for the monitoring of a youth offender's location. The idea here is that via simple Instagram updates (selfie anyone?) with location information it should be possible to keep track of the location of an individual who is out in the community on parole.

This Sinatra-based application [receives pushes](http://instagram.com/developer/realtime/) from the Instagram API and then aggregates this information for a collection of users. 

A task is then run every [~10 minutes](https://github.com/arfon/em-youth-api/blob/master/worker.rb) and if it's been more than an hour since the last check in then the user is reminded via an SMS that they need to post an update. At two hours since check in they are warned again (and further action could be taken).

## Setup

Heroku is your friend with a [MongoHQ addon](https://addons.heroku.com/mongohq) and the [Heroku scheduler](https://addons.heroku.com/scheduler) to run the [background worker](https://github.com/arfon/em-youth-api/blob/master/worker.rb). There's a bunch of environment variables you need to configure:

```
CLIENT_ID:           instagram-client-id
CLIENT_SECRET:       instagram-secret
DOMAIN:              my-app.herokuapp.com
HUB_TOKEN:           a-secure-token
MONGOHQ_URL:         mongodb://blah:blah@nosql.rules.com:1234/awesomeapp
TWILIO_FROM:         +5551234567
TWILIO_SID:          secret-codes
TWILIO_TOKEN:        secret-tokens
```

## There's a client app too!

Kind of. In the spirit of hack days, here's an equally-hacked-together [application](https://github.com/karthikb87/SpyOnKids) that uses this API and a short demo of the direction we were planning on taking this thing:

[![Demo](https://cloud.githubusercontent.com/assets/4483/3140944/13ad0a74-e951-11e3-9cc4-d546ed235c8e.png)](https://www.youtube.com/watch?v=CZWj3xXY95s&feature=em-share_video_user)

#### Prior art

Heavily influenced by this rather nice example application https://github.com/toctan/instahust
