Package.describe({
  summary: 'WebRTC signalling for Meteor'
});

Package.on_use(function (api) {
  // Core packages
  api.use('underscore', ['client', 'server']);
  api.use('backbone', ['client', 'server']);
  api.use('coffeescript', ['client', 'server']);

  // Atmosphere packages
  api.use('streams', ['client', 'server']);

  // Our API
  api.add_files('lib/shim.coffee', ['client']);
  api.add_files('lib/pubsub.coffee', ['client', 'server']);
  api.add_files('lib/streams.coffee', ['client', 'server']);
  api.add_files('lib/client/webrtc_signaller.coffee', 'client');
});

