'use strict';

Package.describe({
  summary: 'WebRTC signalling for Meteor',
  version: '2.0.1',
  name: 'fds:webrtc',
  git: 'https://github.com/foxdog-studios/meteor-webrtc.git'
});

Package.onUse(function (api) {
  api.versionsFrom('1.0');

  api.use([
    'arunoda:streams@0.1.17',
    'coffeescript',
    'mongo-livedata',
    'random',
    'reactive-var',
    'underscore'
  ]);

  api.addFiles('lib/shim.coffee', 'client');
  api.addFiles('lib/streams.coffee');
  api.addFiles('lib/server/permissions.coffee', 'server');
  api.addFiles('lib/client/reactive_data_channel_factory.coffee', 'client');
  api.addFiles('lib/client/webrtc_signaller.coffee', 'client');
  api.addFiles('lib/client/multi_webrtc_signaller_manager.coffee', 'client');
});

Package.onTest(function (api) {
  api.use(['fds:webrtc', 'tinytest']);
});

