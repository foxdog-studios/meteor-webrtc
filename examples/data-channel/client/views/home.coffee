# This is the config used to create the RTCPeerConnection
servers =
  iceServers: [
    url: 'stun:stun.l.google.com:19302'
  ]

config =
  optional: [
    RtpDataChannels: true
  ]

dataChannelConfig =
  reliable: false

# Try and create an RTCPeerConnection if supported
if RTCPeerConnection?
  @webRTCSignaller = new @WebRTCSignaller('mychannel',
                                          servers,
                                          config,
                                          dataChannelConfig)
else
  console.error 'No RTCPeerConnection available :('

Template.home.rendered = ->
  Deps.autorun ->
    message = webRTCSignaller.getMessage()
    return unless message?
    Messages.insert(from: 'Them', message: message, dateCreated: new Date())

Template.home.helpers
  canStart: ->
    'disabled' if webRTCSignaller.started()

  canCall: ->
    'disabled' unless webRTCSignaller.started() and not webRTCSignaller.inCall()

  canSend: ->
    'disabled' unless webRTCSignaller.dataChannelIsOpen()

  messages: ->
    Messages.find({}, {sort: dateCreated: -1})

Template.home.events
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
    webRTCSignaller.sendData(message)
    Messages.insert(from: 'You', message: message, dateCreated: new Date())
    $messageEl.val('')

