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
    where: 'server'
    path: '/'
    action: ->
      newName = getRandomRoomName()
      @response.writeHead 307,
        Location: Router.path 'home', roomName: newName
      @response.end()

  @route 'home',
    path: '/:roomName'

