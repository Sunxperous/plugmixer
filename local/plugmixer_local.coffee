`if (typeof PLUGMIXER_CORE === 'undefined') { PLUGMIXER_CORE = 'https://localhost:8080/core/plugmixer.js'; }`

'use strict'

VERSION = "2.0.0"

# Inject plugmixer.js
$.getScript PLUGMIXER_CORE

class PlugmixerLocal
  PREFIX = 'plugmixer_'
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
          when 'playlists' then loadPlaylists data.id
            
      when 'save'
        switch data.type
          when 'user' then saveUser data.id, data.data
          when 'room' then saveRoom data.id, data.data
          when 'selection' then saveSelection data.id, data.data
          when 'playlists' then savePlaylists data.id, data.data

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
  save = (key, value) ->
    fullKey = PREFIX + userId + '_' + key
    localStorage.setItem fullKey, value

  ###
  # Loads key from local storage.
  ###
  load = (key) ->
    fullKey = PREFIX + userId + '_' + key
    return localStorage.getItem fullKey

  ###
  # Removes key from local storage.
  ###
  remove = (key) ->
    fullKey = PREFIX + userId + '_' + key
    localStorage.removeItem fullKey


  ###
  # Loads the user data associated with 'id'.
  # Creates and returns new user data if does not exist.
  # * Should only run once.
  ###
  loadUser = (id) ->
    userId = id

    # Saves if user is new.
    if !load('')? # Does not require id key for user.
      saveUser '', # Does not require id key for user.
        favorites: []
        lastPlayedIn: 'default'
        selections: []

    userData = load('') # Does not require id key for user.
    respond 'user', JSON.parse userData

  ###
  # Saves user associated with 'id' with the following attributes:
  #   [favorites], "lastPlayedIn", [selections]
  ###
  saveUser = (id, data) ->
    save '', JSON.stringify # Does not require id key for user.
      favorites: data.favorites
      lastPlayedIn: data.lastPlayedIn
      selections: data.selections


  ###
  # Loads the room associated with 'roomKey'.
  ###
  loadRoom = (roomKey) ->
    if !load(roomKey)? # No such roomId...
      roomKey = roomKey.replace /_.+/g, '_default' # Replace with _default key.

    roomData = load roomKey
    respond 'room', JSON.parse roomData

  ###
  # Saves room of key 'roomKey' with the following attributes:
  #   [active, "enabledPlaylists"...]
  ###
  saveRoom = (roomKey, data) ->
    save roomKey, JSON.stringify data

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
    userData = JSON.parse load('') # Does not require id key for user.
    selections = {}

    timestamps = userData.selections
    timestamps.forEach (timestamp) ->
      # userId prefix for consistency with Chrome extension.
      selections[userId + '_' + timestamp] = JSON.parse load(timestamp)

    respond 'selections', selections

  ###
  # Saves selection of id 'timestamp' with the following attributes:
  #   [name, "enabledPlaylists"...]
  ###
  saveSelection = (timestamp, data) ->
    save timestamp, JSON.stringify data

  ###
  # Removes selection of id 'timestamp'.
  ###
  removeSelection = (timestamp) ->
    remove timestamp


  ###
  # Loads the synced playlists of user 'id'.
  # User should have already been loaded before.
  ###
  loadPlaylists = (id) ->
    respond 'playlists', JSON.parse load 'playlists'

  ###
  # Saves the synced playlists with the following attributes:
  #   [ { plugId: "", ytId: "" }, ... ]
  ###
  savePlaylists = (id, data) ->
    save 'playlists', JSON.stringify data

  console.log 'plugmixer_local.js loaded'
