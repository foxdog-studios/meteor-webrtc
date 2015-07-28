'use strict'

byteLength = (str) ->
  # From http://stackoverflow.com/questions/5515869/string-length-in-bytes-in-javascript
  encodeURI(str).split(/%..|./).length - 1

class @ImageVideoUserMediaGetter
  constructor: (mediaConfig = {}) ->
    @_localStreamUrl = new ReactiveVar
    @_mediaConfig = _.defaults mediaConfig,
      audio: false
      video:
        mandatory:
          maxWidth: 320
          maxHeight: 240
          minWidth: 320
          minHeight: 240

  start: ->
    MediaStreamTrack.getSources @_gotMediaSources

  stop: =>
    @_stream?.stop()
    @_localStreamUrl.set null

  _gotMediaSources: (sources) =>
    for source in sources
      if source.kind == 'video' and source.facing == 'user'
        @_mediaConfig.video.optional ?= []
        @_mediaConfig.video.optional.push
        break
    navigator.getUserMedia @_mediaConfig, @_gUMSuccess, @_gUMError

  getStreamUrl: ->
    @_localStreamUrl.get()

  _gUMSuccess: (@_stream) =>
    @_localStreamUrl.set(URL.createObjectURL(@_stream))

  _gUMError: (error) =>
    console.error error


class @ImageStreamer
  constructor: (options = {}) ->
    _.defaults options,
      quality: 0.5
      width: 200
      height: 150
      fps: 30
      shouldSendVideo: true
      dataUrlType: 'image/webp'
    @_dataUrlType = options.dataUrlType
    @_ready = new ReactiveVar false
    @_quality = new ReactiveVar(options.quality)
    @_localImageDataUrl = new ReactiveVar
    @_localImageByteLength = new ReactiveVar
    @_localImageBytesPerSecond = new ReactiveVar
    @_lastUpdatedTime = null
    @_sumOfBytesSinceLastTime = 0
    @_width = new ReactiveVar options.width
    @_height = new ReactiveVar options.height
    @_fps = new ReactiveVar options.fps
    @_timeSinceLastFrame = Infinity
    @_lastFrameAt = 0
    @_shoulSendVideo = new ReactiveVar options.shouldSendVideo
    @_otherVideo = new ReactiveVar(null)
    @_canvas = document.createElement('canvas')
    @_ctx = @_canvas.getContext('2d')

  init: (@_dataChannel, @_videoEl, @_imgEl) =>

    @_ready.set true
    @_sendNextVideo = true

    @_dataChannel.addOnMessageListener (data) =>
      message = JSON.parse(data)
      return unless message?
      switch message.type
        when 'send'
          @_otherVideo.set(message.dataUrl)
          @_dataChannel.sendData(
            JSON.stringify(
              type: 'ack'
            )
          )
        when 'ack'
          @_sendNextVideo = true

  start: =>
    @_nextAnimationFrame = requestAnimationFrame @_update

  stop: =>
    cancelAnimationFrame @_nextAnimationFrame

  ready: =>
    @_ready.get()

  getLocalImageDataUrl: =>
    @_localImageDataUrl.get()

  getLocalImageByteLength: =>
    @_localImageByteLength.get()

  getLocalImageBytesPerSecond: =>
    @_localImageBytesPerSecond.get()

  getOtherVideo: =>
    @_otherVideo.get()

  getQuality: =>
    @_quality.get()

  setQuality: (value) =>
    @_quality.set(value)

  getWidth: =>
    @_width.get()

  getHeight: =>
    @_height.get()

  getFps: =>
    @_fps.get()

  getShouldSendVideo: =>
    @_shoulSendVideo.get()

  setWidth: (width) =>
    @_width.set(width)

  setHeight: (height) =>
    @_height.set(height)

  setFps: (fps) =>
    @_fps.set(fps)

  setShouldSendVideo: (state) =>
    @_shoulSendVideo.set state

  _update: =>
    now = Date.now()
    if not @_shoulSendVideo.get() or  now - @_lastFrameAt < 1000 / @_fps.get()
      requestAnimationFrame @_update
      return
    @_lastFrameAt = now
    width = @_width.get()
    height = @_height.get()
    @_canvas.width = width
    @_canvas.height = height
    @_ctx.drawImage(@_videoEl, 0, 0, width, height)
    data = @_canvas.toDataURL(@_dataUrlType, @_quality.get())
    dataBytesLength = byteLength(data)
    @_localImageByteLength.set dataBytesLength
    @_localImageDataUrl.set data
    if @_dataChannel.isOpen() and @_sendNextVideo
      if @_lastUpdatedTime?
        timeDiff = now - @_lastUpdatedTime
        if timeDiff > 1000
          @_localImageBytesPerSecond.set(
            1000 / timeDiff * @_sumOfBytesSinceLastTime
          )
          @_lastUpdatedTime = now
          @_sumOfBytesSinceLastTime = 0
        else
          @_sumOfBytesSinceLastTime += dataBytesLength
      else
        @_lastUpdatedTime = now
        @_sumOfBytesSinceLastTime += dataBytesLength
      @_dataChannel.sendData(
        JSON.stringify(
          type: 'send'
          dataUrl: data
        )
      )
      # XXX: Should be set to false, trying to find errors atm tho.
      @_sendNextVideo = true

    requestAnimationFrame @_update


