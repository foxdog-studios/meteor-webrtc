Session.set('hasWebRTC', false)

Template.home.created = ->
  # This is the config used to create the RTCPeerConnection
  if Meteor.settings?.public?.servers?
    servers = Meteor.settings.public.servers
  else
    # Default to Google's stun server
    servers =
      iceServers: [
      ]

  rtcPeerConnectionConfig = {}

  dataChannelConfig = {}

  # XXX: hack for Firefox media constraints
  # see https://bugzilla.mozilla.org/show_bug.cgi?id=1006725
  videoConfig =
    mandatory:
      maxWidth: 320
      maxHeight: 240

  mediaConfig =
    video: true
    audio: true

  webRTCSignaller = null
  dataChannel = null
  roomName = Router.current().params.roomName
  Session.set('roomName', roomName)

  # Try and create an RTCPeerConnection if supported
  hasWebRTC = false
  if RTCPeerConnection?
    @_webRTCSignaller = SingleWebRTCSignallerFactory.create(
      share.stream,
      roomName,
      'master',
      servers,
      rtcPeerConnectionConfig,
      mediaConfig
    )
    hasWebRTC = true
  else
    console.error 'No RTCPeerConnection available :('
  Session.set('hasWebRTC', hasWebRTC)
  return unless hasWebRTC

  @_webRTCSignaller.start()


Template.home.destroyed = ->
  @_webRTCSignaller.stop()


Template.home.helpers
  roomName: ->
    roomName = Session.get('roomName')
    if roomName
      Meteor.absoluteUrl(Router.path('home', roomName: roomName)[1...])

  localStream: ->
    return unless Session.get('hasWebRTC')
    Template.instance()._webRTCSignaller.getLocalStream()

  remoteStream: ->
    return unless Session.get('hasWebRTC')
    Template.instance()._webRTCSignaller.getRemoteStream()

  canCall: ->
    return 'disabled' unless Session.get('hasWebRTC')
    webRTCSignaller = Template.instance()._webRTCSignaller
    'disabled' unless webRTCSignaller.started() \
      and not webRTCSignaller.inCall() \
      and not webRTCSignaller.waitingForResponse() \
      and not webRTCSignaller.waitingToCreateAnswer()

  canSend: ->
    return 'disabled' unless Session.get('hasWebRTC')
    'disabled' unless dataChannel.isOpen()

  callText: ->
    unless Session.get('hasWebRTC')
      return "Your browser doesn't suuport Web RTC :("
    webRTCSignaller = Template.instance()._webRTCSignaller
    if webRTCSignaller.waitingForUserMedia()
      return 'Waiting for you to share your camera'
    if webRTCSignaller.waitingForResponse()
      return 'Waiting for response'
    if webRTCSignaller.waitingToCreateAnswer()
      return 'Someone is calling you'
    'Begin call with the other person in the room'


Template.home.events
  'click [name="call"]': (event, template) ->
    event.preventDefault()
    return unless template._webRTCSignaller?
    template._webRTCSignaller.createOffer()

