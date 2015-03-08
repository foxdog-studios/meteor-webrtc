# This is the config used to create the RTCPeerConnection
if Meteor.settings?.public?.servers?
  servers = Meteor.settings.public.servers
else
  # Default to Google's stun server
  servers =
    iceServers: [
    ]

config = {}

# Setting these options makes it not work on firefox
#dataChannelConfig =
#  ordered: false
#  maxRetransmitTime: 0

dataChannelConfig = {}

# XXX: hack for Firefox media constraints
# see https://bugzilla.mozilla.org/show_bug.cgi?id=1006725
videoConfig =
  mandatory:
    maxWidth: 320
    maxHeight: 240

mediaConfig =
  video: videoConfig
  audio: false

webRTCSignaller = null
latencyProfiler = null
dataChannel = null

Session.set('hasWebRTC', false)


class LatencyProfiler
  constructor: (@_dataChannel, @stream, @channel) ->
    @webRTCPingDep = new Deps.Dependency()
    @websocketPingDep = new Deps.Dependency()
    @_timeoutMs = 100

    Deps.autorun =>
      # TODO: FIX THIS
      return
      message = JSON.parse(@_dataChannel.getData())
      return unless message
      if not message.pingBack? and message.pingFrom?
        message.pingBack = true
        @_dataChannel.sendData(JSON.stringify(message))
      else if message.pingBack
        diff = Date.now() - message.pingFrom
        @totalWebRTCPings++
        @numWebRTCPings--
        @sumWebRTCPings += diff
        if @numWebRTCPings > 0
          Meteor.setTimeout =>
            @_pingWebRTC()
          , @_timeoutMs
        @webRTCPingDep.changed()

    WebRTCSignallingStream.on @channel, (message) =>
      if not message.pingBack?
        message.pingBack = true
        WebRTCSignallingStream.emit @channel, message
      else
        diff = Date.now() - message.pingFrom
        @totalWebsocketPings++
        @numWebsocketPings--
        @sumWebsocketPings += diff
        if @numWebsocketPings > 0
          Meteor.setTimeout =>
            @_pingWebSocket()
          , @_timeoutMs
        @websocketPingDep.changed()

  getWebRTCPingAverage: ->
    @webRTCPingDep.depend()
    return unless @totalWebRTCPings > 0
    @sumWebRTCPings / @totalWebRTCPings

  getWebsocketPingAverage: ->
    @websocketPingDep.depend()
    return unless @totalWebsocketPings > 0
    @sumWebsocketPings / @totalWebsocketPings

  _ping: ->
    @_pingWebRTC()
    @_pingWebSocket()

  _getMessage: ->
    pingFrom: Date.now()

  _pingWebRTC: ->
    @_dataChannel.sendData(JSON.stringify(@_getMessage()))

  _pingWebSocket: ->
    @stream.emit @channel, @_getMessage()

  ping: (numPings=1) ->
    @numWebRTCPings = numPings
    @numWebsocketPings = numPings
    @totalWebRTCPings = 0
    @totalWebsocketPings = 0
    @sumWebRTCPings = 0
    @sumWebsocketPings = 0
    @_ping()


Template.home.created = ->
  @_jpegStreamer = new JpegStreamer()
  @_jpegVideoUserMediaGetter = new JpegVideoUserMediaGetter()


Template.home.rendered = ->
  roomName = Router.current().params.roomName
  Session.set('roomName', roomName)
  # Try and create an RTCPeerConnection if supported
  hasWebRTC = false
  if RTCPeerConnection?
    webRTCSignaller = SingleWebRTCSignallerFactory.create(roomName,
                                          'master',
                                          servers,
                                          config,
                                          mediaConfig)
    if MediaStreamTrack?.getSources?
      MediaStreamTrack.getSources (sourceInfos) ->
        videoSources = []
        for sourceInfo in sourceInfos
          if sourceInfo.kind == 'video'
            videoSources.push sourceInfo
        Session.set('videoSources', videoSources)

    hasWebRTC = true
  else
    console.error 'No RTCPeerConnection available :('
  Session.set('hasWebRTC', hasWebRTC)
  return unless hasWebRTC

  webRTCSignaller.start()

  dataChannel = ReactiveDataChannelFactory.fromLabelAndConfig(
    'test',
    dataChannelConfig
  )
  webRTCSignaller.addDataChannel(dataChannel)

  latencyProfiler = new LatencyProfiler(dataChannel,
                                        WebRTCSignallingStream,
                                        "#{roomName}-latency")

  @_jpegVideoUserMediaGetter.start()
  @_jpegStreamer.init(
    dataChannel,
    @find('#local-stream'),
    @find('#jpeg-stream')
  )
  @_jpegStreamer.start()

  #@autorun ->
  #  #message = JSON.parse dataChannel.getData()
  #  #if message?.message?
  #  #  Messages.insert
  #  #    from: 'them'
  #  #    message: message.message
  #  #    datecreated: new Date()


Template.home.helpers
  roomName: ->
    roomName = Session.get('roomName')
    if roomName
      Meteor.absoluteUrl(Router.path('home', roomName: roomName)[1...])

  localStream: ->
    jpegVideoUserMediaGetter = Template.instance()._jpegVideoUserMediaGetter
    jpegVideoUserMediaGetter.getStreamUrl()

  remoteStream: ->
    return unless Session.get('hasWebRTC')
    webRTCSignaller.getRemoteStream()

  canStart: ->
    return 'disabled' unless Session.get('hasWebRTC')
    'disabled' if webRTCSignaller.started()

  canCall: ->
    return 'disabled' unless Session.get('hasWebRTC')
    'disabled' unless webRTCSignaller.started() \
      and not webRTCSignaller.inCall() \
      and not webRTCSignaller.waitingForResponse() \
      and not webRTCSignaller.waitingToCreateAnswer()

  canSend: ->
    return 'disabled' unless Session.get('hasWebRTC')
    'disabled' unless dataChannel.isOpen()

  callText: ->
    return 'Call' unless Session.get('hasWebRTC')
    if webRTCSignaller.waitingForUserMedia()
      return 'Waiting for you to share your camera'
    if webRTCSignaller.waitingForResponse()
      return 'Waiting for response'
    if webRTCSignaller.waitingToCreateAnswer()
      return 'Someone is calling you'
    'Call'

  jpegQuality: ->
    jpegStreamer = Template.instance()._jpegStreamer
    jpegStreamer.getQuality()

  jpegWidth: ->
    jpegStreamer = Template.instance()._jpegStreamer
    jpegStreamer.getWidth()

  jpegHeight: ->
    jpegStreamer = Template.instance()._jpegStreamer
    jpegStreamer.getHeight()

  localJpegSrc: ->
    jpegStreamer = Template.instance()._jpegStreamer
    jpegStreamer.getLocalJpegDataUrl()

  localJpegKb: ->
    jpegStreamer = Template.instance()._jpegStreamer
    bytesLength = jpegStreamer.getLocalJpegByteLength()
    (bytesLength / 1000).toFixed(2)

  localJpegKbps: ->
    jpegStreamer = Template.instance()._jpegStreamer
    bytesPerSecond = jpegStreamer.getLocalJpegBytesPerSecond()
    (bytesPerSecond / 1000).toFixed(2)

  jpegSrc: ->
    jpegStreamer = Template.instance()._jpegStreamer
    if jpegStreamer.ready()
      jpegStreamer.getOtherVideo()

  messages: ->
    Messages.find({}, {sort: dateCreated: -1})

  webRTCAverageLatency: ->
    return unless Session.get('hasWebRTC')
    latencyProfiler.getWebRTCPingAverage()

  websocketAverageLatency: ->
    return unless Session.get('hasWebRTC')
    latencyProfiler.getWebsocketPingAverage()

  videoSources: ->
    Session.get('videoSources')


Template.home.events
  'change [name="camera"]': (event) ->
    event.preventDefault()
    cameraId = $(event.target).val()
    console.log cameraId
    if cameraId != ''
      mediaConfig.video =
        optional: [
          sourceId: cameraId
        ]
    else
      mediaConfig.video = true
    console.log mediaConfig
    webRTCSignaller.setMediaConfig(mediaConfig)

  'click [name="start"]': (event) ->
    event.preventDefault()
    return unless webRTCSignaller?
    webRTCSignaller.start()

  'click [name="call"]': (event) ->
    event.preventDefault()
    return unless webRTCSignaller?
    webRTCSignaller.createOffer()

  'click [name="send"]': (event) ->
    event.preventDefault()
    $messageEl = $('[name="message"]')
    message = $messageEl.val()
    dataChannel.sendData(JSON.stringify(message: message))
    Messages.insert(from: 'You', message: message, dateCreated: new Date())
    $messageEl.val('')

  'click [name="latency"]': (event) ->
    event.preventDefault()
    latencyProfiler.ping(100)

  'input #jpeg-quality': (event, template) ->
    event.preventDefault()
    template._jpegStreamer.setQuality(parseFloat($(event.target).val()))

  'input #jpeg-width': (event, template) ->
    event.preventDefault()
    template._jpegStreamer.setWidth(parseFloat($(event.target).val()))

  'input #jpeg-height': (event, template) ->
    event.preventDefault()
    template._jpegStreamer.setHeight(parseFloat($(event.target).val()))



