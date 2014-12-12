counter = 0

class @WebRTCSignaller
  constructor: (@_messageStream,
                @_id,
                @_servers,
                @_config,
                mediaConfig) ->
    @setMediaConfig(mediaConfig)
    @_started = new ReactiveVar(false)
    @_waitingForResponse = new ReactiveVar(false)
    @_waitingForUserMedia = new ReactiveVar(false)
    @_waitingToCreateAnswer = new ReactiveVar(false)
    @_inCall = new ReactiveVar(false)
    @_localStreamUrl = new ReactiveVar(null)
    @_remoteStream = new ReactiveVar(null)
    @_dataChannels = []
    @_dataChannelsMap = {}
    @_numberOfDataChannels = new ReactiveVar(@_dataChannels.length)
    counter += 1
    @_currentConnectionId = counter

  started: ->
    @_started.get()

  inCall: ->
    @_inCall.get()

  waitingForUserMedia: ->
    @_waitingForUserMedia.get()

  waitingForResponse: ->
    @_waitingForResponse.get()

  waitingToCreateAnswer: ->
    @_waitingToCreateAnswer.get()

  getLocalStream: ->
    @_localStreamUrl.get()

  getRemoteStream: ->
    @_remoteStream.get()

  getDataChannels: ->
    @_numberOfDataChannels.get()
    @_dataChannels

  setMediaConfig: (@mediaConfig) ->

  start: ->
    @_createRtcPeerConnection()

  addDataChannel: (dataChannel) ->
    dataChannel.create(@_rtcPeerConnection)
    @_addDataChannel(dataChannel)

  createOffer: ->
    @_createLocalStream(@_createOffer)
    @_waitingForResponse.set(true)

  requestCall: ->
    @_sendMessage(callMe: true)

  stop: ->
    for dataChannel in @_dataChannels
      dataChannel.close()
    if @_rtcPeerConnection?
      @_rtcPeerConnection.close()
      @_rtcPeerConnection = null
    if @_localStream?
      @_localStream.stop()
      @_localStream = null
    @_started.set(false)
    @_changeInCall(false)

  ignoreMessages: ->
    @_ignoreMessages = true

  _addDataChannel: (dataChannel) ->
    @_dataChannels.push dataChannel
    @_dataChannelsMap[dataChannel.getLabel()] = dataChannel
    @_numberOfDataChannels.set(@_dataChannels.length)

  _sendMessage: (message) ->
    message.from = @_id
    message.connectionId = @_currentConnectionId
    message.toConnectionId = @_currentToConnectionId
    @_messageStream.emit(message)

  handleMessage: (message) =>
    if @_ignoreMessages
      # We've set ignore messages
      return
    if not @_currentToConnectionId? or \
        message.connectionId > @_currentToConnectionId
      @_currentToConnectionId = message.connectionId
    if message.callMe
      @stop()
      @start()
      @createOffer()
    else if message.sdp?
      if @_currentToConnectionId?
        unless message.toConnectionId == @_currentConnectionId
          # SDP message is not for me
          return
      @_handleSDP(JSON.parse(message.sdp))
    else if message.candidate?
      if @_currentToConnectionId?
        unless message.toConnectionId == @_currentConnectionId
          # ICE message not for me
          return
      @_handleIceCandidate(JSON.parse(message.candidate))
    else
      @_logError('Unknown message', meesage)
    @_changeInCall(true)

  _changeInCall: (state) ->
    @_inCall.set state
    if state
      @_waitingForResponse.set(false)

  _handleSDP: (sdp) =>
    remoteDescription = new SessionDescription(sdp)
    if remoteDescription.type == 'offer'
      # Create a new RTCPeerConnection, resetting if necessary. It may exist
      # if we started before we received a call.
      if @_rtcPeerConnection?
        @stop()
      @_createRtcPeerConnection()
    @_rtcPeerConnection.setRemoteDescription(
      remoteDescription,
      @_onRemoteDescriptionSet,
      @_logError
    )

  _handleIceCandidate: (candidate) =>
    iceCandidate = new IceCandidate(candidate)
    @_rtcPeerConnection.addIceCandidate(iceCandidate)

  _onIceCandidate: (event) =>
    return unless event.candidate
    @_sendMessage(candidate: JSON.stringify(event.candidate))

  _createOffer: =>
    @_rtcPeerConnection.createOffer(@_localDescriptionCreated, @_logError)
    @_changeInCall(true)

  _onDataChannel: (event) =>
    dataChannel = @_dataChannelsMap[event.channel.label]
    if dataChannel?
      dataChannel.setDataChannel(event.channel)
    else
      dataChannel = ReactiveDataChannelFactory.fromRtcDataChannel(event.channel)
      @_addDataChannel(dataChannel)

  _onAddStream: (event) =>
    @_remoteStream.set URL.createObjectURL(event.stream)

  _createLocalStream: (callback) ->
    # There may be no media config, for no video/audio
    unless @mediaConfig?
      return callback()
    addStreamToRtcPeerConnection = =>
      @_rtcPeerConnection.addStream(@_localStream)
    if @_localStream? and _.isEqual(@mediaConfig, @_lastMediaConfig)
      # Already have a local stream and the media config has not changed, so
      # we will keep on using the same stream.
      addStreamToRtcPeerConnection()
      return callback()
    @_lastMediaConfig = _.clone(@mediaConfig)
    @_waitingForUserMedia.set(true)
    navigator.getUserMedia @mediaConfig, (stream) =>
      @_localStream = stream
      addStreamToRtcPeerConnection()
      @_localStreamUrl.set URL.createObjectURL(stream)
      if callback?
        callback()
      @_waitingForUserMedia.set(false)
    , =>
      @_waitingForUserMedia.set(false)
      @_logError(arguments...)

  _localDescriptionCreated: (description) =>
    @_rtcPeerConnection.setLocalDescription(description,
                                           @_onLocalDescriptionSet,
                                           @_logError)

  _onLocalDescriptionSet: =>
    @_sendMessage(sdp: JSON.stringify(@_rtcPeerConnection.localDescription))

  _onRemoteDescriptionSet: =>
    return unless @_rtcPeerConnection.remoteDescription.type == 'offer'
    @_waitingToCreateAnswer.set(true)
    @_createLocalStream(@_createAnswer)

  _createAnswer: =>
    @_rtcPeerConnection.createAnswer(@_localDescriptionCreated, @_logError)
    @_waitingToCreateAnswer.set(false)

  _createRtcPeerConnection: ->
    @_currentConnectionId = counter
    @_rtcPeerConnection = new RTCPeerConnection(@_servers, @_config)
    @_rtcPeerConnection.onicecandidate = @_onIceCandidate
    @_rtcPeerConnection.ondatachannel = @_onDataChannel
    @_rtcPeerConnection.onaddstream = @_onAddStream
    @_started.set(true)

  _logError: (message) ->
    console.error message

