`if (typeof PLUGMIXER_CORE === 'undefined') { PLUGMIXER_CORE = 'https://localhost:8080/core/plugmixer.js'; }`

'use strict'

VERSION = "2.1.5"

# Inject plugmixer.js.
inject = document.createElement 'script'
inject.src = PLUGMIXER_CORE
(document.head || document.documentElement).appendChild inject

# Show the icon in the address bar.
chrome.runtime.sendMessage 'plugmixer_show_icon'

class PlugmixerLocal
  PREFIX = ''
  userId = null

  ###
  # Window message listener.
  ###
  window.addEventListener 'message', (event) ->
    try
      data = JSON.parse event.data
    catch e # Not JSON parsable.
      return false
    return if not data.plugmixer?

    switch data.plugmixer
      when 'load'
        switch data.type
          when 'user' then loadUser data.id
          when 'room' then loadRoom data.id
          when 'selections' then loadSelections data.id
          when 'sync' then loadSync data.id
            
      when 'save'
        switch data.type
          when 'user' then saveUser data.id, data.data
          when 'room' then saveRoom data.id, data.data
          when 'selection' then saveSelection data.id, data.data
          when 'sync' then saveSync data.id, data.data

      when 'remove'
        switch data.type
          when 'room' then removeRoom data.id
          when 'selection' then removeSelection data.id


  ###
  # Window message sender.
  ###
  respond = (type, data) ->
    jsonString = JSON.stringify
      plugmixer: 'response'
      type: type
      response: data
    window.postMessage jsonString, '*'

  ###
  # Saves key-value to local storage.
  ###
  save = (key, value, callback) ->
    fullKey = PREFIX + userId + '_' + key
    object = {}
    object[fullKey] = value
    chrome.storage.sync.set object, ->
      if callback? then callback()

  ###
  # Loads key from local storage.
  ###
  load = (key, callback) ->
    fullKey = PREFIX + userId + '_' + key
    chrome.storage.sync.get fullKey, (items) ->
      callback items[fullKey]

  ###
  # Removes key from local storage.
  ###
  remove = (key, callback) ->
    fullKey = PREFIX + userId + '_' + key
    chrome.storage.sync.remove fullKey, ->
      if callback? then callback()


  ###
  # Loads the user data associated with 'id'.
  # Creates and returns new user data if does not exist.
  # * Should only run once.
  ###
  loadUser = (id) ->
    userId = id # Sets userId for this session.

    load '', (user) ->
      # Saves if user is new.
      if !user?
        save '', # Bypass saveUser, call save directly.
          favorites: []
          lastPlayedIn: 'default'
          selections: []
        , ->
          load '', (user_) -> # Gets the new user.
            respond 'user', user_

      else respond 'user', user

  ###
  # Saves user associated with 'id' with the following attributes:
  #   [favorites], "lastPlayedIn", [selections]
  ###
  saveUser = (id, data) ->
    save '', # Does not require id key for user.
      favorites: data.favorites
      lastPlayedIn: data.lastPlayedIn
      selections: data.selections


  ###
  # Loads the room associated with 'roomKey'.
  ###
  loadRoom = (roomKey) ->
    load roomKey, (room) ->
      if !room? # No such roomId...
        roomKey = roomKey.replace /_.+/g, '_default' # Replace with _default key.

      load roomKey, (room_) ->
        respond 'room', room_

  ###
  # Saves room of key 'roomKey' with the following attributes:
  #   [active, "enabledPlaylists"...]
  ###
  saveRoom = (roomKey, data) ->
    save roomKey, data

  ###
  # Removes room of key 'roomKey'.
  ###
  removeRoom = (roomKey) ->
    remove roomKey


  ###
  # Loads the selections of user 'id'.
  # User should have already been loaded before.
  ###
  loadSelections = (id) ->
    load '', (user) ->
      userData = user

      timestamps = userData.selections
      timestamps = timestamps.map (timestamp) ->
        return PREFIX + userId + '_' + timestamp
      chrome.storage.sync.get timestamps, (selections) ->
        respond 'selections', selections          

  ###
  # Saves selection of id 'timestamp' with the following attributes:
  #   [name, "enabledPlaylists"...]
  ###
  saveSelection = (timestamp, data) ->
    save timestamp, data

  ###
  # Removes selection of id 'timestamp'.
  ###
  removeSelection = (timestamp) ->
    remove timestamp


  ###
  # Loads the synced playlists of user 'id'.
  # User should have already been loaded before.
  ###
  loadSync = (id) ->
    load 'sync', (sync) ->
      respond 'sync', sync

  ###
  # Saves the synced playlists with the following attributes:
  #   [ { plugId: "", ytId: "" }, ... ]
  ###
  saveSync = (id, data) ->
    save 'sync', data
