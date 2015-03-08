'use strict'

byteLength = (str) ->
  # From http://stackoverflow.com/questions/5515869/string-length-in-bytes-in-javascript
  encodeURI(str).split(/%..|./).length - 1

class @JpegStreamer
  constructor: (options = {}) ->
    _.defaults options,
      quality: 0.9
    @_ready = new ReactiveVar false
    @_quality = new ReactiveVar(options.quality)
    @_localJpegDataUrl = new ReactiveVar
    @_localJpegByteLength = new ReactiveVar

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

  getOtherVideo: =>
    @_otherVideo.get()

  getQuality: =>
    @_quality.get()

  setQuality: (value) =>
    @_quality.set(value)

  _update: =>
    @_canvas.width = 267
    @_canvas.height = 200
    @_ctx.drawImage(@_videoEl, 0, 0, 267, 200)
    data = @_canvas.toDataURL("image/jpeg", @_quality.get())
    @_localJpegByteLength.set byteLength(data)
    @_localJpegDataUrl.set data
    if @_dataChannel.isOpen() and @_sendNextVideo
      @_dataChannel.sendData(
        JSON.stringify(
          type: 'send'
          dataUrl: data
        )
      )
      @_sendNextVideo = false


