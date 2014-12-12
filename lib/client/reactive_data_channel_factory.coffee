class ReactiveDataChannel
  constructor: ->
    @_isOpen = new ReactiveVar(false)
    @_data = new ReactiveVar(null)

  getLabel: ->
    @_label

  setLabelAndConfig: (@_label, @_config = {}) ->
    if @_dataChannel?
      throw new Error '
        Unable to set label and config, a data channel has aleady been set
      '

  setDataChannel: (rtcDataChannel) ->
    if @_rtcDataChannel?
      @close()
    @_setRtcDataChannel(rtcDataChannel)

  create: (rtcPeerConnection) ->
    unless @_label?
      throw new Error 'Invalid state, no label is set'
    unless @_config?
      throw new Error 'Invalid state, no config is set'
    try
      rtcDataChannel = rtcPeerConnection.createDataChannel(
        @_label
        @_config
      )
    catch error
      console.error("Unable to create data channel:#{error}")
      return
    @_setRtcDataChannel(rtcDataChannel)

  isOpen: ->
    @_isOpen.get()

  getData: ->
    @_data.get()

  sendData: (data) ->
    unless @_rtcDataChannel?
      throw new Error 'No data channel set'
    unless @isOpen()
      throw new Error 'Data channel is not open'
    @_rtcDataChannel.send(data)

  close: ->
    @_rtcDataChannel.close()
    #@_rtcDataChannel = null
    #@_isOpen.set(false)

  _setRtcDataChannel: (@_rtcDataChannel) ->
    @_rtcDataChannel.onmessage = @_handleMessage
    @_rtcDataChannel.onopen = @_handleStateChange
    @_rtcDataChannel.onclose = @_handleStateChange

  _handleMessage: (event) =>
    @_data.set event.data

  _handleStateChange: =>
    readyState = @_rtcDataChannel.readyState
    @_isOpen.set(readyState == 'open')

class @ReactiveDataChannelFactory
  @fromLabelAndConfig: (label, config) ->
    dataChannel = new ReactiveDataChannel()
    dataChannel.setLabelAndConfig(label, config)
    dataChannel

  @fromRtcDataChannel: (rtcDataChannel) ->
    dataChannel = new ReactiveDataChannel()
    dataChannel.setDataChannel(rtcDataChannel)
    dataChannel

