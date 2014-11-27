'use strict'

$.getScript 'https://localhost:8080/core/extendAPI.js'

class Plugmixer
  INITIALIZATION_TIMEOUT = 512
  PLAYLIST_MENU_DIV_ROW  = '#playlist-menu div.row'

  @start: =>
    if $(PLAYLIST_MENU_DIV_ROW).length != 0 and API.getUser().id? and API.extended
      initialize()
    else
      setTimeout @start, INITIALIZATION_TIMEOUT

  initialize = ->
    console.log 'Plugmixer.initialize'
    Listener.initializeWindowMessage()
    User.initialize()


  ###
  # User management.
  ###
  class User
    @id: null
    @favorites: []
    @selections: []
    @lastPlayedIn: 'default' # Assume last played in default room.

    @initialize: ->
      @id = API.getUser().id
      Storage.load 'user', @id

    @update: (response) ->
      @favorites = response.favorites || @favorites
      @selections = response.selections || @selections
      @lastPlayedIn = response.lastPlayedIn || @lastPlayedIn


  ###
  # Room management.
  ###
  class Room
    @id: null
    @active: 1

    @initialize: ->
      @id = API.getRoom().id
      Playlists.initialize()
      Storage.load 'room', @id

    getStatus = =>
      status = Playlists.getEnabled().map (playlist) ->
        return playlist.name
      status.unshift @active
      return status

    @update: (response) -> # Response is a Room data array.
      if !response? # Non-existing room...
        @active = 1
        @save()
      else # Existing room...
        @active = response.splice(0, 1)[0]
        Playlists.update response # Remainder of response contains playlist data.
      Listener.initializeAPI()

    @save: ->
      Storage.save 'room', @id, getStatus()


  ###
  # Event listeners.
  ###
  class Listener

    ###
    # Window message listener.
    ###
    @initializeWindowMessage: ->
      window.addEventListener 'message', (event) ->
        try
          data = JSON.parse event.data
        catch e # Return if data is not JSON parsable.
          return false

        return if !data.plugmixer?

        if data.plugmixer == 'response'
          switch data.type
            when 'user' # Should only happen once.
              User.update data.response
              Room.initialize()
            when 'room' then Room.update data.response

    ###
    # API listener.
    ###
    @initializeAPI: ->
      Helper.TitleText.update()
      API.on API.ADVANCE, (data) ->
        Helper.TitleText.update()
        if data.dj? and data.dj.username == API.getUser().username
          Playlists.activateRandom()


  ###
  # Miscellaneous features.
  ###
  class Helper
    @TitleText: class TitleText
      TITLE_TEXT = '#now-playing-media .bar-value'
      @update: ->
        $(TITLE_TEXT).attr 'title', $(TITLE_TEXT).text() # Hover text.


  ###
  # Window message passer to storage.
  ###
  class Storage
    @load: (type, query) ->
      jsonString = JSON.stringify
        plugmixer: 'load'
        type: type
        id: query
      window.postMessage jsonString, '*'

    @save: (type, query, data) ->
      jsonString = JSON.stringify
        plugmixer: 'save'
        type: type
        id: query
        data: data
      window.postMessage jsonString, '*'


  ###
  # Playlists management.
  ###
  class Playlists
    playlists = []
    activePlaylist = null

    @initialize: ->
      playlists = API.getPlaylists().map (playlist) ->
        return new Playlist(playlist)
      activePlaylist = @getActivated()

    @getEnabled = ->
      return playlists.filter (playlist, index) ->
        return playlist.enabled

    @getActivated = ->
      return (playlists.filter (playlist, index) ->
        return playlist.isActive()
      )[0]

    @update: (playlistNames) ->
      playlists.forEach (playlist) ->
        enable = false
        for playlistName in playlistNames
          if playlist.name == playlistName then enable = true
        if enable then playlist.enable() else playlist.disable()

      @activateAnother() # Activates a random playlist even if current selected is active. 

    @activateAnother: (playlist) ->
      return if playlist? and playlist != activePlaylist # Do nothing if not the same playlist.
      @activateRandom() # if !@getActivated().enabled

    @activateRandom: ->
      return if Room.active != 1 # Do nothing if not active.
      playlist = @getRandom()
      activePlaylist = playlist
      if playlist? then playlist.activate()

    @getRandom = ->
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

    ###
    # Playlist object.
    ###
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
          if @isActivating() or @isActive() # Only activate another if this playlist is active.
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
