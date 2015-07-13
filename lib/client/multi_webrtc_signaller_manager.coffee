class MessageStreamProxy
  constructor: (@_channelName, @_to) ->

  emit: (message) ->
    message._to = @_to
    WebRTCSignallingStream.emit(@_channelName, message)


# A signaller who will only listen to messages from master on it's channel
class @SingleWebRTCSignallerFactory
  @create: (channelName, id, servers, config, mediaConfig, options) ->
    signaller = new WebRTCSignaller(
        new MessageStreamProxy(channelName, 'master'),
        id,
        servers,
        config,
        mediaConfig,
        options
    )
    WebRTCSignallingStream.on channelName, (message) ->
      if message._to == id or message.callMe
        signaller.handleMessage(message)
    signaller


# A signaller who will listen to messages from anyone.
class @MultiWebRTCSignallerManager
  constructor: (@_channelName, @_id, @_servers, @_config, mediaConfig) ->
    @_connectionMap = {}
    @setMediaConfig(mediaConfig)
    WebRTCSignallingStream.on @_channelName, @_handleMessage
    @_data = new ReactiveVar()

  setMediaConfig: (@_mediaConfig) ->

  getData: ->
    @_data.get()

  requestCall: ->
    WebRTCSignallingStream.emit @_channelName,
      callMe: true

  _handleMessage: (message) =>
    signallerConnection = @_connectionMap[message.from]
    unless signallerConnection?
      signaller = new WebRTCSignaller(
        new MessageStreamProxy(@_channelName, message.from),
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

