class share.MessageStreamProxy
  constructor: (@_stream, @_channelName, @_to) ->

  emit: (message) ->
    message._to = @_to
    @_stream.emit @_channelName, message

