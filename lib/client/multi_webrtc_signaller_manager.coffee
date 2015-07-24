# A signaller who will listen to messages from anyone.
class @MultiWebRTCSignallerManager
  constructor: (@_stream, @_channelName, @_id, @_servers, @_config, mediaConfig) ->
    @_connectionMap = {}
    @setMediaConfig(mediaConfig)
    @_stream.on @_channelName, @_handleMessage
    @_data = new ReactiveVar()

  setMediaConfig: (@_mediaConfig) ->

  getData: ->
    @_data.get()

  requestCall: ->
    @_stream.emit @_channelName,
      callMe: true

  _handleMessage: (message) =>
    signallerConnection = @_connectionMap[message.from]
    unless signallerConnection?
      signaller = new WebRTCSignaller(
        new share.MessageStreamProxy(@_stream, @_channelName, message.from),
        @_id,
        @_servers,
        @_config,
        @_mediaConfig
      )
      signallerConnection =
        signaller: signaller
        dataChannels: {}
      @_connectionMap[message.from] = signallerConnection

      Tracker.autorun =>
        dataChannels = signaller.getDataChannels()
        for dataChannel in dataChannels
          unless signallerConnection[dataChannel.getLabel()]?
            Tracker.autorun =>
              @_data.set dataChannel.getData()
    signaller = signallerConnection.signaller

    signaller.handleMessage(message)

