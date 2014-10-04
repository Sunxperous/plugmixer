'use strict'

# Inject plugmixer.js.
inject = document.createElement 'script'
inject.src = 'https://75a1ab5a424a760224d0f125f4199c9f585306bb.googledrive.com/host/0ByHWCSTdXEMLZUh1aHdkSkZVcTQ/plugmixer.js'
(document.head || document.documentElement).appendChild inject

window.addEventListener 'message', (event) ->
  try
    data = JSON.parse event.data
  catch e
    return false

  return if not data.plugmixer?
  switch data.plugmixer
    when 'load'
      switch data.type
        when 'user'
          loadUser data.load
        when 'room'
          loadRoom data.load
          
    when 'save'
      switch data.type
        when 'user'
          saveUser data.save
        when 'room'
          saveRoom data.save

respond = (type, data) ->
  window.postMessage JSON.stringify(
    plugmixer: 'loaded'
    type: type
    loaded: data
  ), '*'

###
# Returns user of key 'userId' with the following attributes:
#   [favorites], "lastPlayedIn", [groups]
# Creates and returns new user if 'userId' does not exist.
###
loadUser = (data) ->
  if !localStorage.getItem(data.userId)? # No such userId - this is a new user.
    # Saves the new userId and saves their default roomKey.
    saveUser
      userId: data.userId
      favorites: []
      lastPlayedIn: 'default'
      groups: []
    data.playlists.unshift 1
    saveRoom
      roomKey: data.userId + '_default'
      info: data.playlists

  userData = localStorage.getItem data.userId
  respond 'user', JSON.parse userData

###
# Returns room of key 'roomKey' with the following attributes:
#   [active, "enabledPlaylists"...]
# Returns roomKey 'default' if 'roomKey' does not exist.
###
loadRoom = (data) ->
  roomKey = data.roomKey
  if !localStorage.getItem(roomKey)? # No such roomKey.
    roomKey = roomKey.replace /_.+/g, '_default'

  roomData = localStorage.getItem roomKey
  respond 'room', JSON.parse roomData

###
# Saves user of key 'userId' with the following attributes:
#   [favorites], "lastPlayedIn", [groups]
###
saveUser = (data) ->
  localStorage.setItem data.userId, JSON.stringify
    favorites: data.favorites
    lastPlayedIn: data.lastPlayedIn
    groups: data.groups

###
# Saves room of key 'roomKey' with the following attributes:
#   [active, "enabledPlaylists"...]
###
saveRoom = (data) ->
  localStorage.setItem data.roomKey, JSON.stringify data.info

console.log 'plugmixer_local.js loaded'
