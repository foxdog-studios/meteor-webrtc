Session.set('hasWebRTC', false)

Template.ImageStream.created = ->
  @_imageStreamer = new ImageStreamer()
  @_imageVideoUserMediaGetter = new ImageVideoUserMediaGetter()

  # This is the config used to create the RTCPeerConnection
  if Meteor.settings?.public?.servers?
    servers = Meteor.settings.public.servers
  else
    # Default to Google's stun server
    servers =
      iceServers: [
      ]

  config = {}

  # XXX: hack for Firefox media constraints
  # see https://bugzilla.mozilla.org/show_bug.cgi?id=1006725
  videoConfig =
    mandatory:
      maxWidth: 320
      maxHeight: 240

  mediaConfig =
    video: videoConfig
    audio: false

  dataChannel = null

  signallingChannelName = Router.current().url
  Session.set('roomName', Router.current().params.roomName)
  # Try and create an RTCPeerConnection if supported
  hasWebRTC = false
  if RTCPeerConnection?
    @_webRTCSignaller = SingleWebRTCSignallerFactory.create(
        share.stream,
        signallingChannelName,
        'master',
        servers,
        config,
        mediaConfig)
    hasWebRTC = true
  else
    console.error 'No RTCPeerConnection available :('
  Session.set('hasWebRTC', hasWebRTC)
  return unless hasWebRTC

  @_webRTCSignaller.start()


Template.ImageStream.rendered = ->
  dataChannelConfig = {}
  dataChannel = ReactiveDataChannelFactory.fromLabelAndConfig(
    'test',
    dataChannelConfig
  )
  @_webRTCSignaller.addDataChannel(dataChannel)
  @_imageVideoUserMediaGetter.start()
  @_imageStreamer.init(
    dataChannel,
    @find('#local-stream'),
    @find('#image-stream')
  )
  @_imageStreamer.start()


Template.ImageStream.destroyed = ->
  console.log 'stopping'
  @_imageStreamer.stop()
  @_imageVideoUserMediaGetter.stop()
  @_webRTCSignaller.stop()


Template.ImageStream.helpers
  roomName: ->
    roomName = Session.get('roomName')
    if roomName
      Meteor.absoluteUrl(Router.path('ImageStream', roomName: roomName)[1...])

  localStream: ->
    imageVideoUserMediaGetter = Template.instance()._imageVideoUserMediaGetter
    imageVideoUserMediaGetter.getStreamUrl()

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

  imageQuality: ->
    imageStreamer = Template.instance()._imageStreamer
    imageStreamer.getQuality()

  imageWidth: ->
    imageStreamer = Template.instance()._imageStreamer
    imageStreamer.getWidth()

  imageHeight: ->
    imageStreamer = Template.instance()._imageStreamer
    imageStreamer.getHeight()

  dataChannelFps: ->
    imageStreamer = Template.instance()._imageStreamer
    imageStreamer.getFps()

  localImageSrc: ->
    imageStreamer = Template.instance()._imageStreamer
    imageStreamer.getLocalImageDataUrl()

  localImageKB: ->
    imageStreamer = Template.instance()._imageStreamer
    bytesLength = imageStreamer.getLocalImageByteLength()
    (bytesLength / 1000).toFixed(2)

  localImageKBps: ->
    imageStreamer = Template.instance()._imageStreamer
    bytesPerSecond = imageStreamer.getLocalImageBytesPerSecond()
    (bytesPerSecond / 1000).toFixed(2)

  localImageKbps: ->
    imageStreamer = Template.instance()._imageStreamer
    bytesPerSecond = imageStreamer.getLocalImageBytesPerSecond()
    (bytesPerSecond * 8 / 1000).toFixed(2)

  imageSrc: ->
    imageStreamer = Template.instance()._imageStreamer
    if imageStreamer.ready()
      imageStreamer.getOtherVideo()


Template.ImageStream.events
  'click [name="call"]': (event) ->
    event.preventDefault()
    webRTCSignaller = Template.instance()._webRTCSignaller
    return unless webRTCSignaller?
    webRTCSignaller.createOffer()

  'input #image-quality': (event, template) ->
    event.preventDefault()
    template._imageStreamer.setQuality(parseFloat($(event.target).val()))

  'input #image-width': (event, template) ->
    event.preventDefault()
    template._imageStreamer.setWidth(parseFloat($(event.target).val()))

  'input #image-height': (event, template) ->
    event.preventDefault()
    template._imageStreamer.setHeight(parseFloat($(event.target).val()))

  'input #data-channel-fps': (event, template) ->
    event.preventDefault()
    template._imageStreamer.setFps(parseFloat($(event.target).val()))

