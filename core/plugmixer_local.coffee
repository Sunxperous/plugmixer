'use strict'

# Inject plugmixer.js
$.getScript 'https://localhost:8080/core/plugmixer.js'

class PlugmixerLocal
  PREFIX = 'plugmixer_'
  userId = null

  window.addEventListener 'message', (event) ->
    try
      data = JSON.parse event.data
    catch e # Not JSON parsable.
      return false
    return if not data.plugmixer?

    switch data.plugmixer
      when 'load'
        console.log 'PlugmixerLocal.message load', data
        switch data.type
          when 'user'
            loadUser data.id
          when 'room'
            loadRoom data.id
            
      when 'save'
        console.log 'PlugmixerLocal.message save', data
        switch data.type
          when 'user'
            saveUser data.id, data.data
          when 'room'
            saveRoom data.id, data.data

  respond = (type, data) ->
    jsonString = JSON.stringify
      plugmixer: 'response'
      type: type
      response: data
    window.postMessage jsonString, '*'

  save = (key, value) ->
    console.log 'PlugmixerLocal.save', key, value
    fullKey = PREFIX + userId + '_' + key
    localStorage.setItem fullKey, value

  load = (key) ->
    console.log 'PlugmixerLocal.load', key
    fullKey = PREFIX + userId + '_' + key
    return localStorage.getItem fullKey

  ###
  #
  # Creates and returns new user if 'id' does not exist.
  # Should only run once.
  ###
  loadUser = (id) ->
    console.log 'PlugmixerLocal.loadUser', id
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
  # Saves user of key 'userId' with the following attributes:
  #   [favorites], "lastPlayedIn", [groups]
  ###
  saveUser = (id, data) ->
    console.log 'PlugmixerLocal.saveUser', id, data
    save id, JSON.stringify
      favorites: data.favorites
      lastPlayedIn: data.lastPlayedIn
      selections: data.selections

  ###
  #
  ###
  loadRoom = (id) ->
    console.log 'PlugmixerLocal.loadRoom', id
    if !load(id)? # No such roomKey.
      id = id.replace /_.+/g, '_default'

    roomData = load id
    respond 'room', JSON.parse roomData


  ###
  # Saves room of key 'roomKey' with the following attributes:
  #   [active, "enabledPlaylists"...]
  ###
  saveRoom = (id, data) ->
    console.log 'PlugmixerLocal.saveRoom', id, data
    save id, JSON.stringify data

  console.log 'plugmixer_local.js loaded'
