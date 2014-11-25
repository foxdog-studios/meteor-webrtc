'use strict';

Package.describe({
  summary: 'WebRTC signalling for Meteor',
  name: 'fds:webrtc',
  version: '1.0.0',
  git: 'https://github.com/foxdog-studios/meteor-webrtc.git'
});

Package.onUse(function (api) {
  api.versionsFrom('1.0');

  api.use([
    'arunoda:streams@0.1.17',
    'backbone@1.0.0',
    'coffeescript',
    'mongo-livedata',
    'underscore'
  ]);

  api.addFiles('lib/shim.coffee', 'client');
  api.addFiles('lib/pubsub.coffee');
  api.addFiles('lib/streams.coffee');
  api.addFiles('lib/server/permissions.coffee', 'server');
  api.addFiles('lib/client/webrtc_signaller.coffee', 'client');
});

Package.onTest(function (api) {
  api.use(['fds:webrtc', 'tinytest']);
});

