# This is the config used to create the RTCPeerConnection
if Meteor.settings?.public?.servers?
  servers = Meteor.settings.public.servers
else
  # Default to Google's stun server
  servers =
    iceServers: [
    ]

config = {}

dataChannelConfig =
  ordered: false
  maxRetransmitTime: 0

# XXX: hack for Firefox media constraints
# see https://bugzilla.mozilla.org/show_bug.cgi?id=1006725
videoConfig = if navigator.userAgent.search("Firefox") > -1
  console.log 'firefox'
  width:
    min: 320
    max: 320
  height:
    min: 240
    max: 240
else
  console.log 'not firefox'
  mandatory:
    maxWidth: 320
    maxHeight: 240

mediaConfig =
  video: videoConfig
  audio: false

webRTCSignaller = null
latencyProfiler = null

Session.set('hasWebRTC', false)


class LatencyProfiler
  constructor: (@webRTCSignaller, @stream, @channel) ->
    @webRTCPingDep = new Deps.Dependency()
    @websocketPingDep = new Deps.Dependency()

    Deps.autorun =>
      message = JSON.parse(@webRTCSignaller.getMessage())
      return unless message
      if not message.pingBack? and message.pingFrom?
        message.pingBack = true
        webRTCSignaller.sendData(JSON.stringify(message))
      else if message.pingBack
        diff = Date.now() - message.pingFrom
        @totalWebRTCPings++
        @numWebRTCPings--
        @sumWebRTCPings += diff
        if @numWebRTCPings > 0
          Meteor.setTimeout =>
            @_pingWebRTC()
          , 1000
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
          , 1000
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
    @webRTCSignaller.sendData(JSON.stringify(@_getMessage()))

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



Template.home.rendered = ->
  roomName = Router.current().params.roomName
  Session.set('roomName', roomName)
  # Try and create an RTCPeerConnection if supported
  hasWebRTC = false
  if RTCPeerConnection?
    webRTCSignaller = new WebRTCSignaller(roomName,
                                          servers,
                                          config,
                                          dataChannelConfig,
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

  latencyProfiler = new LatencyProfiler(webRTCSignaller,
                                        WebRTCSignallingStream,
                                        "#{roomName}-latency")

  Deps.autorun ->
    message = JSON.parse(webRTCSignaller.getMessage())
    return unless message?
    if message.message?
      Messages.insert(from: 'Them', message: message.message,
                      dateCreated: new Date())


Template.home.helpers
  roomName: ->
    roomName = Session.get('roomName')
    if roomName
      Meteor.absoluteUrl(Router.path('home', roomName: roomName)[1...])

  localStream: ->
    return unless Session.get('hasWebRTC')
    webRTCSignaller.getLocalStream()

  remoteStream: ->
    return unless Session.get('hasWebRTC')
    webRTCSignaller.getRemoteStream()

  canStart: ->
    return 'disabled' unless Session.get('hasWebRTC')
    'disabled' if webRTCSignaller.started()

  canCall: ->
    return 'disabled' unless Session.get('hasWebRTC')
    'disabled' unless webRTCSignaller.started() \
      and not webRTCSignaller.inCall()

  canSend: ->
    return 'disabled' unless Session.get('hasWebRTC')
    'disabled' unless webRTCSignaller.dataChannelIsOpen()

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
    webRTCSignaller.sendData(JSON.stringify(message: message))
    Messages.insert(from: 'You', message: message, dateCreated: new Date())
    $messageEl.val('')

  'click [name="latency"]': (event) ->
    event.preventDefault()
    latencyProfiler.ping(10)

