'use strict'

byteLength = (str) ->
  # From http://stackoverflow.com/questions/5515869/string-length-in-bytes-in-javascript
  encodeURI(str).split(/%..|./).length - 1

class @JpegVideoUserMediaGetter
  constructor: (mediaConfig = {}) ->
    @_localStreamUrl = new ReactiveVar
    @_mediaConfig = _.defaults mediaConfig,
      audio: false
      video: true

  start: ->
    navigator.getUserMedia @_mediaConfig, @_gUMSuccess, @_gUMError

  getStreamUrl: ->
    @_localStreamUrl.get()

  _gUMSuccess: (stream) =>
    @_localStreamUrl.set(URL.createObjectURL(stream))

  _gUMError: (error) =>
    console.error error


class @JpegStreamer
  constructor: (options = {}) ->
    _.defaults options,
      quality: 0.5
      width: 100
      height: 75
    @_ready = new ReactiveVar false
    @_quality = new ReactiveVar(options.quality)
    @_localJpegDataUrl = new ReactiveVar
    @_localJpegByteLength = new ReactiveVar
    @_localJpegBytesPerSecond = new ReactiveVar
    @_lastUpdatedTime = null
    @_sumOfBytesSinceLastTime = 0
    @_width = new ReactiveVar options.width
    @_height = new ReactiveVar options.height

  init: (@_dataChannel, @_videoEl, @_imgEl) =>
    @_canvas = document.createElement('canvas')

    @_ctx = @_canvas.getContext('2d')
    @_ready.set true

    @_otherVideo = new ReactiveVar(null)

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
    Meteor.setInterval @_update, 1000 / 30

  ready: =>
    @_ready.get()

  getLocalJpegDataUrl: =>
    @_localJpegDataUrl.get()

  getLocalJpegByteLength: =>
    @_localJpegByteLength.get()

  getLocalJpegBytesPerSecond: =>
    @_localJpegBytesPerSecond.get()

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

  setWidth: (width) =>
    @_width.set(width)

  setHeight: (height) =>
    @_height.set(height)

  _update: =>
    width = @_width.get()
    height = @_height.get()
    @_canvas.width = width
    @_canvas.height = height
    @_ctx.drawImage(@_videoEl, 0, 0, width, height)
    data = @_canvas.toDataURL("image/webp", @_quality.get())
    dataBytesLength = byteLength(data)
    @_localJpegByteLength.set dataBytesLength
    @_localJpegDataUrl.set data
    now = Date.now()
    if @_dataChannel.isOpen() and @_sendNextVideo
      if @_lastUpdatedTime?
        timeDiff = now - @_lastUpdatedTime
        if timeDiff > 1000
          @_localJpegBytesPerSecond.set(
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
      @_sendNextVideo = false


