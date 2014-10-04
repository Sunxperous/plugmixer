'use strict'

INITIALIZATION_TIMEOUT     = 256
INITIALIZATION_COUNT_LIMIT = 192
FADE_DURATION              = 0.3
FADE_OPACITY               = 0.4
PLAYLIST_MENU_DIV_ROW      = '#playlist-menu div.row'
ROOM_BAR_FAVORITE          = '#room-bar .favorite'
ACTIVATE_BUTTON_CLASS      = '.activate-button'
PLAYLIST_SPAN_COUNT        = 'span.count'
PLAYLIST_SPAN_NAME         = 'span.name'
PLAYLIST_ACTIVE_CLASS      = 'icon-active-active'

###
# Waits for API to be ready and playlists to load before initialization.
###
initialization_count = 0
waitForPlaylists = ->
  initialization_count++
  if $(PLAYLIST_MENU_DIV_ROW).length != 0 && API.getUser()?
    console.log 'plugmixer.js initialized'
    Plugmixer.initialize()
  else if initialization_count <= INITIALIZATION_COUNT_LIMIT
    console.log 'waiting for playlists...'
    setTimeout waitForPlaylists, INITIALIZATION_TIMEOUT

class Plugmixer
  playlists      = null
  active         = 1
  userId         = null
  userData       = {}
  favorites      = []
  groups         = []
  groupInUse     = null
  lastPlayedIn   = 'default'
  roomId         = window.location.pathname.slice 1, -1

  ###
  # Initialization of Plugmixer.
  ###
  @initialize: =>
    # Initialize user's playlists.
    playlistsDom = $(PLAYLIST_MENU_DIV_ROW)
    playlists = playlistsDom.map (i, pDom) ->
      new Playlist($(pDom))

    userId = API.getUser().id

    # Request for data of type user.
    @load 'user',
      userId: userId
      playlists: $.makeArray(playlists).map (playlist) =>
        playlist.name

    window.addEventListener 'message', (event) =>
      try
        data = JSON.parse event.data
      catch e
        return false

      if data.plugmixer? and data.plugmixer == 'loaded'
        switch data.type
          when 'user'
            if data.loaded?
              data = data.loaded
              lastPlayedIn = data.lastPlayedIn || lastPlayedIn
              favorites = data.favorites || favorites
              @updateFavorites()
              @requestActivePlaylists()
          when 'room'
            if data.loaded?
              data = data.loaded
              active = data.splice(0, 1)[0]
              @enablePlaylists data # Parse and apply loaded playlists.
          when 'group' then

    # API ADVANCE event.
    # Changes value of song alt text, and activates random playlist.
    API.on API.ADVANCE, (obj) =>
      $('#now-playing-media .bar-value').attr 'title', $('#now-playing-media .bar-value').text()
      if obj.dj? and obj.dj.username == API.getUser().username and active
        @activateRandomPlaylist()

  ###
  # Enables the playlists with the same name.
  ###
  @enablePlaylists: (enabledPlaylists) =>
    for playlist in playlists
      enable = false
      for enabledPlaylist in enabledPlaylists
        if playlist.name == enabledPlaylist
          enable = true
      if enable then playlist.enable() else playlist.disable()

    @activateAnotherIfNotEnabled()

  ###
  # Request status and playlist information for the room / default.
  ###
  @requestActivePlaylists: =>
    roomId = if favorites.indexOf(roomId) > -1 then roomId else 'default'
    @load 'room', 
      roomKey: userId + '_' + roomId

  ###
  # Overwrites active playlists for the room / default.
  ###
  @saveActivePlaylists: =>
    @updateFavorites()
    roomId = if @isCurrentRoomFavorite() then roomId else 'default'
    @save 'room',
      roomKey: userId + '_' + roomId
      info: @getEnabledPlaylistsNameUnshift active # Array of active and playlist names.

  ###
  # Plugmixer load requests.
  ###
  @load: (type, data) =>
    window.postMessage JSON.stringify(
      plugmixer: 'load'
      type: type
      load: data
    ), '*'

  ###
  # Plugmixer save requests.
  ###
  @save: (type, data) =>
    window.postMessage JSON.stringify(
      plugmixer: 'save'
      type: type
      save: data
    ), '*'

  ###
  # Saves user data.
  ###
  @saveUser: =>
    @save 'user',
      userId: userId
      favorites: favorites
      groups: groups
      lastPlayedIn: if @isCurrentRoomFavorite() then lastPlayedIn else 'default'

  ###
  # Verifies and updates whether room is favorite.
  ###
  @updateFavorites: =>
    changedFavorite = false
    # Was a favorite...
    if favorites.indexOf(roomId) > -1 and not @isCurrentRoomFavorite()
      favorites.splice favorites.indexOf(roomId), 1
      changedFavorite = true
    # Now a favorite...
    else if favorites.indexOf(roomId) == -1 and @isCurrentRoomFavorite()
      favorites.push roomId
      changedFavorite = true
    @saveUser() if changedFavorite

  ###
  # Activates another playlist if current active playlist is not enabled.
  # Does not do so if Plugmixer is inactive.
  ###
  @activateAnotherIfNotEnabled: =>
    return if !active
    activePlaylist = playlists.filter(Playlist.isActivated)[0] # Only one anyway.
    @activateRandomPlaylist() if !activePlaylist.enabled

  @activateRandomPlaylist: =>
    playlist = @getRandomPlaylist()
    if playlist? then playlist.activate()

  @getRandomPlaylist: =>
    countSum = 0
    enabledPlaylists = @getEnabledPlaylists()
    for playlist in enabledPlaylists
      countSum += playlist.count()
    playlistCount = playlists.length
    weightedSelect = Math.floor(Math.random() * countSum)
    for playlist in enabledPlaylists
      if weightedSelect < playlist.count()
        return playlist
      weightedSelect -= playlist.count()
    null

  @getEnabledPlaylists: =>
    return playlists.filter Playlist.isEnabled

  @toggleStatus: =>
    active = if !!active then 0 else 1

  ###
  # Returns an array of enabled playlists' names, with value at index 0.
  ###
  @getEnabledPlaylistsNameUnshift: (value) =>
    enabledPlaylists = $.makeArray(@getEnabledPlaylists()).map (playlist) =>
      return playlist.name
    enabledPlaylists.unshift value
    return enabledPlaylists

  @isCurrentRoomFavorite: =>
    return $(ROOM_BAR_FAVORITE).hasClass 'selected'

  class Playlist
    constructor: (@dom) ->
      @name = @dom.children(PLAYLIST_SPAN_NAME).text()
      @enabled = false

      @applyToggleOnClick()

    count: ->
      return parseInt(@dom.children(PLAYLIST_SPAN_COUNT).text())

    disable: ->
      @enabled = false
      @dom.fadeTo(FADE_DURATION, FADE_OPACITY)

    enable: ->
      @enabled = true
      @dom.fadeTo(FADE_DURATION, 1)

    toggle: ->
      if @enabled
        @disable()
        Plugmixer.activateAnotherIfNotEnabled()
      else
        @enable()
        @activate() if Plugmixer.getEnabledPlaylists().length == 1
      Plugmixer.saveActivePlaylists()

    @isEnabled = (index) ->
      # this refers to filtered objects.
      return this.enabled

    @isActivated = (index) ->
      # this refers to filtered objects.
      return this.dom.children(ACTIVATE_BUTTON_CLASS)
        .children('i.icon').eq(0).hasClass PLAYLIST_ACTIVE_CLASS

    applyToggleOnClick: ->
      @dom.children(PLAYLIST_SPAN_COUNT).click (event) =>
        @toggle()

    clickDom: ->
      mouseEvent = document.createEvent 'MouseEvents'
      mouseEvent.initMouseEvent 'mouseup', true, true, window,
        1, 0, 0, 0, 0, false, false, false, false, 0, null
      @dom[0].dispatchEvent(mouseEvent)

    activate: ->
      @clickDom()
      $(ACTIVATE_BUTTON_CLASS).eq(0).click()
      API.chatLog 'Next playing from ' + @name + '.'

  # class Popup
  #   constructor: ->
  #     @html = '<div id="plugmixer">'

waitForPlaylists()
