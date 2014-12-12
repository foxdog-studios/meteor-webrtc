if Meteor.settings?.public?.servers?
  servers = Meteor.settings.public.servers
else
  # Default to Google's stun server
  servers =
    iceServers: [
    ]

config = {}

dataChannelConfig =
  ordered: false
  maxRetransmitTime: 0

STATE_START = 0
STATE_MOVE = 1
STATE_END = 2

class DrawingCanvas
  constructor: (@_canvas) ->
    @_ctx = @_canvas.getContext '2d'
    @_strokes = []
    @_lastStroke = null
    resize = =>
      height = window.innerHeight
      width = window.innerWidth
      if height > width
        height *= width / height
      else
        width *= height / width
      @_canvas.width = width
      @_canvas.height = height
    resize()
    $(window).resize resize

  _getScreenX: (relativeX) ->
    @_canvas.width * relativeX

  _getScreenY: (relativeY) ->
    @_canvas.height * relativeY

  _renderStrokes: =>
    requestAnimationFrame(@_renderStrokes)
    return if @_strokes.length == 0
    @_ctx.stokeStyle = '#000'
    @_ctx.beginPath()
    if @_lastStroke?
      @_ctx.moveTo(@_getScreenX(@_lastStroke.x), @_getScreenY(@_lastStroke.y))
    for stroke in @_strokes
      @_ctx.lineTo(@_getScreenX(stroke.x), @_getScreenY(stroke.y))
      if stroke.state = STATE_START or stroke.state == STATE_END
        @_lastStroke = null
      else
        @_lastStroke = stroke
    @_ctx.stroke()
    @_strokes.length = 0

  addStroke: (stroke) ->
    @_strokes.push stroke

  renderStrokes: ->
    @_renderStrokes()


Template.multiDraw.rendered = ->
  webRTCSignaller = new MultiWebRTCSignallerManager(
    'drawing',
    'master',
    servers,
    config
  )

  canvas = @find('#drawing')

  drawingCanvas = new DrawingCanvas(canvas)
  drawingCanvas.renderStrokes()

  @autorun =>
    message = webRTCSignaller.getData()
    if message?
      stroke = JSON.parse message
      drawingCanvas.addStroke stroke

Template.drawer.rendered = ->
  @_id = Random.hexString(20)
  webRTCSignaller = SingleWebRTCSignallerFactory.create(
    'drawing',
    @_id,
    servers,
    config
  )
  @_dataChannel = ReactiveDataChannelFactory.fromLabelAndConfig(
    'drawing',
    dataChannelConfig
  )
  webRTCSignaller.start()
  webRTCSignaller.addDataChannel(@_dataChannel)
  webRTCSignaller.createOffer()

  canvas = @find('#drawer')

  drawingCanvas = new DrawingCanvas(canvas)
  drawingCanvas.renderStrokes()

  @_sendEventData = (event, state) =>
    if event.originalEvent?.changedTouches?
      x = event.originalEvent.changedTouches[0].pageX
      y = event.originalEvent.changedTouches[0].pageY
    else
      x = event.pageX
      y = event.pageY
    x -= $(event.target).offset().left
    y -=  $(event.target).offset().top
    stroke =
      x: x / $(canvas).width()
      y: y / $(canvas).height()
      state: state
    @_dataChannel.sendData JSON.stringify stroke
    drawingCanvas.addStroke(stroke)

  $(window).on 'mouseup', =>
    @_mouseDown = false

Template.drawer.events
  'mousedown #drawer': (event, template) ->
    template._mouseDown = true
    template._sendEventData(event, STATE_START)

  'touchstart #drawer': (event, template) ->
    template._sendEventData(event, STATE_START)

  'mousemove #drawer': (event, template) ->
    if template._mouseDown
      template._sendEventData(event, STATE_MOVE)

  'touchmove #drawer': (event, template) ->
    template._sendEventData(event, STATE_MOVE)

  'mouseup #drawer': (event, template) ->
    if template._mouseDown
      template._sendEventData(event, STATE_END)

  'touchend #drawer': (event, template) ->
    template._sendEventData(event, STATE_END)

