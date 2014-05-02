class @WebRTCSignaller
  constructor: (@channelName, @servers, @config, @dataChannelConfig) ->
    WebRTCSignallingStream.on @channelName, @handleMessage
    @_started = false
    @startedDep = new Deps.Dependency()
    @_message = null
    @messageDep = new Deps.Dependency()

  started: ->
    @startedDep.depend()
    @_started

  getMessage: ->
    @messageDep.depend()
    @_message

  sendMessage: (message) ->
    WebRTCSignallingStream.emit(@channelName, message)

  handleMessage: (message) =>
    # Create our RTCPeerConnection if necessary
    unless @rtcPeerConnection?
      @createRtcPeerConnection()
    if message.sdp?
      @handleSDP(message.sdp)
    else if message.candidate?
      @handleIceCandidate(message.candidate)
    else
      @logError('Unknown message', meesage)

  handleSDP: (sdp) =>
    remoteDescription = new RTCSessionDescription(sdp)
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

  onDataChannel: (event) =>
    @dataChannel = event.channel
    @dataChannel.onmessage = @handleDataChannelMessage
    @dataChannel.onopen = @handleRecieveChannelChange
    @dataChannel.onclose = @handleRecieveCh1annelChange

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
    @dataChannel.onopen = @handleSendChannelStateChange
    @dataChannel.onclose = @handleSendChannelStateChange

  sendData: (data) ->
    @dataChannel.send(data)

  handleSendChannelStateChange: =>
    readyState = @dataChannel.readyState
    console.log "sendchannel state: #{readyState}"

  handleRecieveChannelChange: =>
    readyState = @dataChannel.readyState
    console.log "readychannel state: #{readyState}"

  logError: (message) ->
    console.error message

