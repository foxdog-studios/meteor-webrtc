FIRST = [
  'rumbling'
  'accountants'
  'tax'
  'appraisal'
  'business'
  'legal'
  'sedimentary'
  'twiglet'
  'mars'
  'bounty'
  'twix'
  'smurf'
]

SECOND = [
  'triceratops'
  'philip'
  'squirrel'
  'gravy'
  'cheddar'
  'swiss'
  'log'
  'rubbish'
  'disclaimer'
  'waiver'
  'parking'
  'council'
  'research'
  'of'
  'from'
  'via'
  'underneath'
  'inside'
  'looking'
  'wandering'
  'observing'
  'confusing'
]

THIRD = [
  'everyone'
  'nobody'
  'auditors'
  'coconut'
  'bagel'
  'fromage'
  'jiggly'
  'warlock'
  'beard'
  'koala'
  'biscuit'
  'sensitivity'
  'risk'
  'view'
]

getRandomRoomName = ->
  parts = []
  for wordArray in [FIRST, SECOND, THIRD]
    parts.push Random.choice(wordArray)
  parts.join('-')

Router.map ->
  @route 'root',
    onBeforeAction: ->
      roomName = getRandomRoomName()
      Router.go 'home', roomName: roomName
    path: '/'

  @route 'home',
    path: '/:roomName'

