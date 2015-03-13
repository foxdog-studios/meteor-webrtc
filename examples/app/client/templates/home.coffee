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
dataChannel = null

Session.set('hasWebRTC', false)

Template.home.created = ->
  @_imageStreamer = new ImageStreamer()
  @_imageVideoUserMediaGetter = new ImageVideoUserMediaGetter()


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

  @_imageVideoUserMediaGetter.start()
  @_imageStreamer.init(
    dataChannel,
    @find('#local-stream'),
    @find('#image-stream')
  )
  @_imageStreamer.start()


Template.home.helpers
  roomName: ->
    roomName = Session.get('roomName')
    if roomName
      Meteor.absoluteUrl(Router.path('home', roomName: roomName)[1...])

  localStream: ->
    imageVideoUserMediaGetter = Template.instance()._imageVideoUserMediaGetter
    imageVideoUserMediaGetter.getStreamUrl()

  remoteStream: ->
    return unless Session.get('hasWebRTC')
    webRTCSignaller.getRemoteStream()

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
    unless Session.get('hasWebRTC')
      return "Your browser doesn't suuport Web RTC :("
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


Template.home.events
  'click [name="call"]': (event) ->
    event.preventDefault()
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

