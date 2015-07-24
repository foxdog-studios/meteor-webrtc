meteor-webrtc
=============

WebRTC signalling for Meteor with Reactivity!

[Demo](http://webrtc-signalling.meteor.com/) - in `examples/app`


How to use
----------

*Shared*
```javascript
stream = new Meteor.Stream('signalling');
```

*Server*
```javascript
var allowAll = function () { return true; };
stream.permissions.read(allowAll);
stream.permissions.write(allowAll);
```

*Client*
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
  stream,
  signallingChannelName,
  'master',
  servers,
  config,
  mediaConfig
);

// Creates the rtcPeerConnection
webRTCSignaller.start();

// ... Whenever someone wants to inititate a call (make a connection)
webRTCSignaller.createOffer();

// Then if you have written similar code for a client using the same
// signallingChannelName then it should connect for a call.
```

For more see the app in the example directorty, which is also running on the
[demo site](http://webrtc-signalling.meteor.com/)

