# Identifies unique connections in one session
counter = 0
# Identifies the session
sessionId = Random.hexString(20)

class @WebRTCSignaller
  constructor: (@_messageStream,
                @_id,
                @_servers,
                @_config,
                mediaConfig,
                options = {}) ->

    _.defaults options,
      audioBandwidth: null
      videoBandwidth: null
    @_audioBandwidth = options.audioBandwidth
    @_videoBandwidth = options.videoBandwidth
    @setMediaConfig(mediaConfig)
    @_started = new ReactiveVar(false)
    @_waitingForResponse = new ReactiveVar(false)
    @_waitingForUserMedia = new ReactiveVar(false)
    @_waitingToCreateAnswer = new ReactiveVar(false)
    @_inCall = new ReactiveVar(false)
    @_lastGetUserMediaError = new ReactiveVar(null)
    @_localStreamUrl = new ReactiveVar(null)
    @_remoteStream = new ReactiveVar(null)
    @_dataChannels = []
    @_pendingDataChannels = []
    @_dataChannelsMap = {}
    @_numberOfDataChannels = new ReactiveVar(@_dataChannels.length)
    counter += 1
    @_currentConnectionId =
      sessionId: sessionId
      counter: counter

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

  lastGetUserMediaError: ->
    @_lastGetUserMediaError.get()

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
    if @_rtcPeerConnection?
      dataChannel.create(@_rtcPeerConnection)
    else
      @_pendingDataChannels.push dataChannel
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

  _connectionIdsEqual: (connectionA, connectionB) ->
    return true unless connectionA? and connectionB?
    connectionA.counter == connectionB.counter and \
      connectionA.sessionId == connectionB.sessionId

  handleMessage: (message) =>
    if @_ignoreMessages
      # We've set ignore messages
      console.log('ignoring message')
      return
    if not @_currentToConnectionId? or \
        message.connectionId.counter > @_currentToConnectionId.counter or \
        message.connectionId.sessionId != @_currentToConnectionId.sessionId
      @_currentToConnectionId = message.connectionId
    if message.callMe
      @stop()
      @start()
      @createOffer()
    else if message.sdp?
      if @_currentToConnectionId?
        unless @_connectionIdsEqual(message.toConnectionId,
                                    @_currentConnectionId)
          # SDP message is not for me
          console.log('SDP no for me')
          return
      @_handleSDP(JSON.parse(message.sdp))
    else if message.candidate?
      if @_currentToConnectionId?
        unless @_connectionIdsEqual(message.toConnectionId,
                                   @_currentConnectionId)
          # ICE message not for me
          console.log('ICE not for me')
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
    @_rtcPeerConnection.addIceCandidate iceCandidate, @_iceSuccess, @_iceFailure

  _iceSuccess: ->
    console.log 'added ice candidiate'

  _iceFailure: ->
    console.error 'Failed to add ice candidate', arguments

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
    , (error) =>
      @_waitingForUserMedia.set(false)
      @_lastGetUserMediaError.set(error)
      @_logError(error)

  _localDescriptionCreated: (description) =>
    description.sdp = @_maybeSetBandwidthLimits(description.sdp)
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
    @_rtcPeerConnection = new RTCPeerConnection(@_servers, @_config)
    @_rtcPeerConnection.onicecandidate = @_onIceCandidate
    @_rtcPeerConnection.ondatachannel = @_onDataChannel
    @_rtcPeerConnection.onaddstream = @_onAddStream
    for dataChannel in @_dataChannels
      dataChannel.create(@_rtcPeerConnection)
    @_started.set(true)

  _logError: (message) ->
    console.error message

  _maybeSetBandwidthLimits: (sdp) ->
    if @_audioBandwidth?
      sdp = sdp.replace(
        /a=mid:audio\r\n/g, "a=mid:audio\r\nb=AS:#{@_audioBandwidth}\r\n"
      )
    if @_videoBandwidth?
      sdp = sdp.replace(
        /a=mid:video\r\n/g, "a=mid:video\r\nb=AS:#{@_videoBandwidth}\r\n"
      )
    sdp

