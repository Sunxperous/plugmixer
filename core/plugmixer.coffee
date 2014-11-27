'use strict'

$.getScript 'https://localhost:8080/core/extendAPI.js'

class Plugmixer
  INITIALIZATION_TIMEOUT = 512
  PLAYLIST_MENU_DIV_ROW  = '#playlist-menu div.row'

  @start: =>
    if $(PLAYLIST_MENU_DIV_ROW).length != 0 and API.getUser().id? and API.extended
      initialize()
    else
      console.log 'Plugmixer.start'
      setTimeout @start, INITIALIZATION_TIMEOUT

  initialize = ->
    console.log 'Plugmixer.initialize'
    Listener.initializeWindowMessage()
    User.initialize()

  class User
    @id: null
    @favorites: []
    @selections: []
    @lastPlayedIn: 'default'

    @initialize: ->
      console.log 'User.initialize'
      @id = API.getUser().id
      Storage.load 'user', @id

    @update: (response) ->
      console.log 'User.update', response
      @favorites = response.favorites || @favorites
      @selections = response.selections || @selections
      @lastPlayedIn = response.lastPlayedIn || @lastPlayedIn

  class Room
    @id: null
    @active: 1

    @initialize: ->
      console.log 'Room.initialize'
      @id = API.getRoom().id
      Playlists.initialize()
      Storage.load 'room', @id

    getStatus = =>
      console.log 'Room.getStatus'
      status = Playlists.getEnabled().map (playlist) ->
        return playlist.name
      status.unshift @active
      return status

    @update: (response) -> # Response is a Room data array.
      console.log 'Room.update', response
      if !response? # Non-existing room
        @active = 1
        @save()
      else
        @active = response.splice(0, 1)[0]
        Playlists.update response # Remainder of response contains playlist data.
      Listener.initializeAPI()

    @save: ->
      console.log 'Room.save'
      Storage.save 'room', @id, getStatus()

  class Listener
    @initializeWindowMessage: ->
      window.addEventListener 'message', (event) ->
        try
          data = JSON.parse event.data
        catch e # Return if data is not JSON parsable.
          return false

        return if !data.plugmixer?

        if data.plugmixer == 'response'
          console.log 'Listener.message response', data
          switch data.type
            when 'user'
              User.update data.response
              Room.initialize()
            when 'room' then Room.update data.response

    @initializeAPI: ->
      Helper.TitleText.update()
      API.on API.ADVANCE, (data) ->
        Helper.TitleText.update()
        if data.dj? and data.dj.username == API.getUser().username
          Playlists.activateRandom()

  class Helper
    @TitleText: class TitleText
      TITLE_TEXT = '#now-playing-media .bar-value'
      @update: ->
        console.log 'Helper.TitleText.update'
        $(TITLE_TEXT).attr 'title', $(TITLE_TEXT).text() # Hover text.

  class Storage
    @load: (type, query) ->
      console.log 'Storage.load', type, query
      jsonString = JSON.stringify
        plugmixer: 'load'
        type: type
        id: query
      window.postMessage jsonString, '*'

    @save: (type, query, data) ->
      console.log 'Storage.save', type, query, data
      jsonString = JSON.stringify
        plugmixer: 'save'
        type: type
        id: query
        data: data
      window.postMessage jsonString, '*'

  class Playlists
    playlists = []
    activePlaylist = null

    @initialize: ->
      console.log 'Playlists.initialize'
      playlists = API.getPlaylists().map (playlist) ->
        return new Playlist(playlist)
      activePlaylist = @getActivated()

    @getEnabled = ->
      console.log 'Playlists.getEnabled'
      return playlists.filter (playlist, index) ->
        return playlist.enabled

    @getActivated = ->
      console.log 'Playlists.getActivated'
      return (playlists.filter (playlist, index) ->
        return playlist.isActive()
      )[0]

    @update: (playlistNames) ->
      console.log 'Playlists.update', playlistNames
      playlists.forEach (playlist) ->
        enable = false
        for playlistName in playlistNames
          if playlist.name == playlistName then enable = true
        if enable then playlist.enable() else playlist.disable()

      @activateAnother()

    @activateAnother: (playlist) ->
      console.log 'Playlists.activateAnother'
      return if playlist? and playlist != activePlaylist # Do nothing if not the same playlist.
      @activateRandom() # if !@getActivated().enabled

    @activateRandom: ->
      console.log 'Playlists.activateRandom'
      return if Room.active != 1 # Do nothing if not active.
      playlist = @getRandom()
      activePlaylist = playlist
      if playlist? then playlist.activate()

    @getRandom = ->
      console.log 'Playlists.getRandom'
      countSum = 0
      activePlaylists = @getEnabled()
      for playlist in activePlaylists
        countSum += playlist.count()
      weightedSelect = Math.floor(Math.random() * countSum)
      for playlist in activePlaylists
        if weightedSelect < playlist.count()
          return playlist
        weightedSelect -= playlist.count()
      null

    # Playlist object.
    class Playlist
      FADE_DURATION   = 0.3
      FADE_OPACITY    = 0.4
      SPAN_COUNT      = 'span.count'
      ACTIVE_CLASS    = 'icon-check-purple'
      ACTIVATE_BUTTON = '.activate-button'
      SPINNER         = '.spinner'

      constructor: (playlist) ->
        @dom = playlist.$
        @name = playlist.name
        @enabled = true

        @dom.children(SPAN_COUNT).mouseup (event) => # Mouseup to prevent parent triggers.
          @toggle()
          event.preventDefault()
          event.stopPropagation();

      count: ->
        return parseInt(@dom.children(SPAN_COUNT).text())

      disable: ->
        @enabled = false
        @dom.fadeTo(FADE_DURATION, FADE_OPACITY)

      enable: ->
        @enabled = true
        @dom.fadeTo(FADE_DURATION, 1)

      toggle: ->
        if @enabled
          @disable()
          # Only activate another if this playlist is active.
          if @isActivating() or @isActive()
            Playlists.activateAnother(@)
        else
          @enable()
          if Playlists.getEnabled().length == 1 and !@isActive()
            Playlists.activateRandom()
        Room.save()

      clickDom: ->
        mouseEvent = document.createEvent 'MouseEvents'
        mouseEvent.initMouseEvent 'mouseup', true, true, window,
          1, 0, 0, 0, 0, false, false, false, false, 0, null
        @dom[0].dispatchEvent(mouseEvent)

      activate: ->
        @clickDom()
        $(ACTIVATE_BUTTON).eq(0).click()
        API.chatLog "Next playing from #{@name}"

      isActivating: ->
        return @dom.children(SPINNER).length > 0
      isActive: ->
        return @dom.children(ACTIVATE_BUTTON)
          .children('i.icon').eq(0).hasClass ACTIVE_CLASS

console.log 'plugmixer.js loaded'
Plugmixer.start()
