FIRST = 'abcdefghijklmnopqrstuvwxyz'

SECOND = 'aeiou'

THIRD = FIRST

getRandomRoomName = ->
  parts = []
  for wordArray in [FIRST, SECOND, THIRD]
    parts.push Random.choice(wordArray)
  parts.join('')

Router.configure
  layoutTemplate: 'layout'

Router.map ->
  @route 'root',
    where: 'server'
    path: '/'
    action: ->
      newName = getRandomRoomName()
      @response.writeHead 307,
        Location: Router.path 'home', roomName: newName
      @response.end()

  @route 'imageRoot',
    where: 'server'
    path: '/image-stream'
    action: ->
      newName = getRandomRoomName()
      @response.writeHead 307,
        Location: Router.path 'ImageStream', roomName: newName
      @response.end()

  @route 'multiDraw',
    path: '/multi_draw'

  @route 'drawer',
    path: '/drawer'

  @route 'home',
    path: '/:roomName'

  @route 'ImageStream',
    path: '/image-stream/:roomName'

