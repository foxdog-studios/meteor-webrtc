'use strict';

Package.describe({
  summary: 'WebRTC signalling for Meteor',
  version: '3.1.1',
  name: 'fds:webrtc',
  git: 'https://github.com/foxdog-studios/meteor-webrtc.git'
});


Package.onUse(function (api) {
  api.versionsFrom('1.0');

  api.use([
    'coffeescript',
    'mongo-livedata',
    'random',
    'reactive-var',
    'underscore'
  ]);

  api.addFiles(
    [
      'lib/client/shim.coffee',

      'lib/client/image_streamer.coffee',
      'lib/client/message_stream_proxy.coffee',
      'lib/client/multi_webrtc_signaller_manager.coffee',
      'lib/client/reactive_data_channel_factory.coffee',
      'lib/client/single_web_rtc_signaller_factory.coffee',
      'lib/client/webrtc_signaller.coffee'
    ],
    'client'
  );
});


Package.onTest(function (api) {
  api.use(['fds:webrtc', 'tinytest']);
});

