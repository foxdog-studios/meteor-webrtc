'use strict'

class @UserMediaGetter
  constructor: (@_mediaConfig) ->

  getUserMedia: ->
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


