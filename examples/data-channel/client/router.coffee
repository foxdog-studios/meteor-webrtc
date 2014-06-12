FIRST = 'abcdefghijklmnopqrstuvwxyz'

SECOND = 'aeiou'

THIRD = FIRST

getRandomRoomName = ->
  parts = []
  for wordArray in [FIRST, SECOND, THIRD]
    parts.push Random.choice(wordArray)
  parts.join('')

Router.map ->
  @route 'root',
    onBeforeAction: ->
      roomName = getRandomRoomName()
      Router.go 'home', roomName: roomName
    path: '/'

  @route 'home',
    path: '/:roomName'

