class @WebRTCSignaller
  constructor: (@channelName, @servers, @config, @dataChannelConfig) ->
    WebRTCSignallingStream.on @channelName, @handleMessage
    @_started = false
    @startedDep = new Deps.Dependency()
    @_inCall = false
    @inCallDep = new Deps.Dependency()
    @_message = null
    @messageDep = new Deps.Dependency()
    @_dataChannelOpen = false
    @dataChannelDep = new Deps.Dependency()

  started: ->
    @startedDep.depend()
    @_started

  inCall: ->
    @inCallDep.depend()
    @_inCall

  getMessage: ->
    @messageDep.depend()
    @_message

  dataChannelIsOpen: ->
    @dataChannelDep.depend()
    @_dataChannelOpen

  sendMessage: (message) ->
    WebRTCSignallingStream.emit(@channelName, message)

  handleMessage: (message) =>
    if message.sdp?
      @handleSDP(message.sdp)
    else if message.candidate?
      @handleIceCandidate(message.candidate)
    else
      @logError('Unknown message', meesage)
    @_changeInCall(true)

  _changeInCall: (state) ->
    @_inCall = state
    @inCallDep.changed()

  handleSDP: (sdp) =>
    remoteDescription = new RTCSessionDescription(sdp)
    if remoteDescription.type == 'offer'
      # Create a new RTCPeerConnection
      if @rtcPeerConnection?
        @stop()
      @createRtcPeerConnection()
    @rtcPeerConnection.setRemoteDescription(remoteDescription,
                                            @onRemoteDescriptionSet,
                                            @logError)

  handleIceCandidate: (candidate) =>
    iceCandidate = new RTCIceCandidate(candidate)
    @rtcPeerConnection.addIceCandidate(iceCandidate)

  onIceCandidate: (event) =>
    return unless event.candidate
    @sendMessage(candidate: event.candidate)

  createOffer: =>
    @rtcPeerConnection.createOffer(@localDescriptionCreated, @logError)
    @_changeInCall(true)

  onDataChannel: (event) =>
    @dataChannel = event.channel
    @dataChannel.onmessage = @handleDataChannelMessage
    @dataChannel.onopen = @handleDataChannelStateChange
    @dataChannel.onclose = @handleDataChannelStateChange

  handleDataChannelMessage: (event) =>
    @_message = event.data
    @messageDep.changed()

  localDescriptionCreated: (description) =>
    @rtcPeerConnection.setLocalDescription(description,
                                           @onLocalDescriptionSet,
                                           @logError)

  onLocalDescriptionSet: =>
    @sendMessage(sdp: @rtcPeerConnection.localDescription)

  onRemoteDescriptionSet: =>
    return unless @rtcPeerConnection.remoteDescription.type == 'offer'
    @rtcPeerConnection.createAnswer(@localDescriptionCreated, @logError)

  createRtcPeerConnection: ->
    @rtcPeerConnection = new RTCPeerConnection(@servers, @config)
    @rtcPeerConnection.onicecandidate = @onIceCandidate
    @rtcPeerConnection.ondatachannel = @onDataChannel
    @_started = true
    @startedDep.changed()

  start: ->
    @createRtcPeerConnection()
    try
      @dataChannel = @rtcPeerConnection.createDataChannel('dataChannel',
                                                          @dataChannelConfig)
    catch error
      @logError(error)

    @dataChannel.onmessage = @handleDataChannelMessage
    @dataChannel.onopen = @handleDataChannelStateChange
    @dataChannel.onclose = @handleDataChannelStateChange

  stop: ->
    @dataChannel.close()
    @rtcPeerConnection.close()
    @rtcPeerConnection = null
    @_started = false
    @startedDep.changed()
    @_changeInCall(false)

  sendData: (data) ->
    @dataChannel.send(data)

  handleDataChannelStateChange: =>
    readyState = @dataChannel.readyState
    console.log "data channel state: #{readyState}"
    @_dataChannelOpen = readyState == 'open'
    @dataChannelDep.changed()

  logError: (message) ->
    console.error message

