'use strict'

API.on API.DJ_ADVANCE, (obj) ->
  if obj.dj? and obj.dj.username == API.getUser().username
    window.postMessage 'plugmixer_user_playing', '*'

window.postMessage
  about: 'plugmixer_user_info',
  userId: API.getUser().id
  , '*'

window.addEventListener 'message', (event) ->
  if event.data.about == 'plugmixer_send_chat'
    API.chatLog event.data.message