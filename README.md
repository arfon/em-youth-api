EM Youth API
======

Built as part of the [Adler Planetarium's](http://www.adlerplanetarium.org/) [Civic Hack Day](http://civichack.adlerplanetarium.org/2014/) on 31 May 2014. This is a simple application that monitors the Instagram API for updates from a group of users (who have authorised the application to receive updates from their account) and then makes this information available to others.

### Why?

Because ankle bracelets are embarrassing, demoralising and often more than is required for the monitoring of a youth offender's location. The idea here is that via simple Instagram updates (selfie anyone?) with location information it should be possible to keep track of the location of an individual who is out in the community on parole.

This Sinatra-based application [receives pushes](http://instagram.com/developer/realtime/) from the Instagram API and then aggregates this information for a collection of users. 

A task is then run every [~10 minutes](https://github.com/arfon/em-youth-api/blob/master/worker.rb) and if it's been more than an hour since the last check in then the user is reminded via an SMS that they need to post an update. At two hours since check in they are warned again (and further action could be taken).

#### Prior art

Heavily influence by this rather nice example application https://github.com/toctan/instahust
