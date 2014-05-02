class Pubsub
  constructor: ->
    _.extend @, Backbone.Events

@WebRTCSignallingPubSub = new Pubsub()

