# A signaller who will only listen to messages from master on it's channel
class @SingleWebRTCSignallerFactory
  @create: (stream, channelName, id, servers, config, mediaConfig, options) ->
    signaller = new WebRTCSignaller(
        new share.MessageStreamProxy(stream, channelName, 'master'),
        id,
        servers,
        config,
        mediaConfig,
        options
    )
    stream.on channelName, (message) ->
      if message._to == id or message.callMe
        signaller.handleMessage(message)
    signaller

