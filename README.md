meteor-webrtc
=============

WebRTC signalling for Meteor with Reactivity!

[Demo](http://webrtc-signalling.meteor.com/) - in `examples/app`


How to use
----------

```javascript


var signallingChannelName = "uniqueStringTokenForThisSignallingChannel";

var rtcPeerConnectionConfig = {};

// Config passed to getUserMedia()
//
// Could be null, then no media will be requested, i.e., for when you only
// want data channels, or one way video/audio calls.

var mediaConfig = {
  video: true,
  audio: true
};

var webRTCSignaller = SingleWebRTCSignallerFactory.create(
                                            signallingChannelName,
                                            'master',
                                            servers,
                                            config,
                                            mediaConfig);
// Creates the rtcPeerConnection
webRTCSignaller.start();

// ... Whenever someone wants to inititate a call (make a connection)
webRTCSignaller.createOffer();

// Then if you have written similar code for a client using the same
// signallingChannelName then it should connect for a call.
```

For more see the app in the example directorty, which is also running on the
[demo site](http://webrtc-signalling.meteor.com/)

TODO
----

- Allow for different signalling channels. At the moment there is one global,
  public signalling channel using a [Meteor
  Stream](http://arunoda.github.io/meteor-streams/). Nice for demos, not really
  for a real app. Could use a user/connection based system backed a collection,
  and pass in the signalling channel to the signaller, so they would only need
  to implement the same interface.

