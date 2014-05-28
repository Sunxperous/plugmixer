'use strict'

INITIALIZATION_TIMER = 256
INITIALIZATION_TTL   = 192
FADE_DURATION        = 0.3
FADE_OPACITY         = 0.4

ttl = 0
waitForPlaylists = ->
  ttl++
  if $('#playlist-menu div.row').length != 0
    Plugmixer.initialize()
  else if ttl <= INITIALIZATION_TTL
    console.log 'waiting for playlists...'
    setTimeout waitForPlaylists, INITIALIZATION_TIMER

waitForPlaylists()

class Plugmixer
  playlists = null
  active = 1
  userId = null
  userData = {}
  favorites = []
  selections = []
  selectionInUse = null
  lastPlayedIn = 'default'

  @initialize: =>
    # Read playlists.
    playlistsDom = $('#playlist-menu div.row')
    playlists = playlistsDom.map (i, pDom) ->
      new Playlist($(pDom))

    # Listeners.
    window.addEventListener 'message', @listenFromMessenger
    chrome.runtime.onMessage.addListener @listenFromBackground

    # Inject apimessenger.js.
    inject = document.createElement 'script'
    inject.src = chrome.extension.getURL 'apimessenger.js'
    (document.head || document.documentElement).appendChild inject

  @listenFromBackground: (message, sender, sendResponse) =>
    if message == 'plugmixer_toggle_status'
      @toggleStatus()
      sendResponse(if !!active then 'plugmixer_make_active' else 'plugmixer_make_inactive')
    else if message == 'plugmixer_get_selections'
      sendResponse 
        'selections': selections,
        'activePlaylists': @getEnabledPlaylists()
    else if message.about == 'plugmixer_save_selection'
      selectionId = @saveSelection message.name
      sendResponse 
        about: 'plugmixer_selection_saved'
        selectionId: selectionId
    else if message.about == 'plugmixer_delete_selection'
      @deleteSelection message.selectionId
      sendResponse 'plugmixer_selection_deleted'
    else if message.about == 'plugmixer_choose_selection'
      @chooseSelection message.selectionId

  @listenFromMessenger: (event) =>
    if !!active and event.data == 'plugmixer_user_playing'
      playlist = @getRandomPlaylist()
      if playlist? then playlist.activate()
    else if event.data.about? and event.data.about == 'plugmixer_user_info'
      userId = event.data.userId
      @load() # Ready to load from storage.

  @showIcon: =>
    if !!active # Active
      chrome.runtime.sendMessage('plugmixer_make_active')
    else # Inactive
      chrome.runtime.sendMessage('plugmixer_make_inactive')

  @toggleStatus: =>
    active = if !!active then 0 else 1
    @savePlaylists() # Also saves status.
    @showIcon()

  @getEnabledPlaylists: =>
    return $.makeArray(playlists.filter(Playlist.isEnabled)).map (playlist) =>
      playlist.name

  @getEnabledPlaylistsUnshift: (value) =>
    enabledPlaylists = @getEnabledPlaylists()
    enabledPlaylists.unshift value
    return enabledPlaylists

  @chooseSelection: (selectionId) =>
    chrome.storage.sync.get selectionId, (data) =>
      for playlist in playlists
        enable = false
        for enabledPlaylist in data[selectionId]
          if playlist.name == enabledPlaylist
            enable = true
        if enable then playlist.enable() else playlist.disable()
      @savePlaylists()

  @saveSelection: (name) =>
    selectionId = Date.now().toString()
    selection = {}
    selection[selectionId] = @getEnabledPlaylistsUnshift name
    chrome.storage.sync.set selection

    # Save selection under user.
    selections.unshift selectionId
    @save 'selections', selections

    return selectionId

  @deleteSelection: (selectionId) =>
    selections.splice(selections.indexOf(selectionId), 1)
    chrome.storage.sync.remove selectionId
    @save 'selections', selections

  @getRandomPlaylist: =>
    countSum = 0
    for playlist in playlists.filter Playlist.isEnabled
      countSum += playlist.count
    playlistCount = playlists.length
    weightedSelect = Math.floor(Math.random() * countSum)
    for playlist in playlists.filter Playlist.isEnabled
      if weightedSelect < playlist.count
        return playlist
      weightedSelect -= playlist.count
    null

  @getRoomId: =>
    id = window.location.pathname
    return id.substring 1, id.length - 1

  @isCurrentRoomFavorite: =>
    $('#room-bar .favorite').hasClass 'selected'

  @saveRoomPlaylist: (name) =>
    roomPlaylists = {}
    roomPlaylists[userId + '_' + name] = @getEnabledPlaylistsUnshift active
    chrome.storage.sync.set roomPlaylists

  @updateFavorites: (callback) =>
    if @isCurrentRoomFavorite()
      if favorites.indexOf(@getRoomId()) == -1 # Not listed as favorite.
        favorites.push @getRoomId()
        @save 'favorites', favorites
        callback lastPlayedIn, true
      else callback @getRoomId(), false
    else # Not a favorite...
      if favorites.indexOf(@getRoomId()) > -1 # But listed as favorite.
        favorites.splice favorites.indexOf(@getRoomId()), 1
        @save 'favorites', favorites
        chrome.storage.sync.remove userId + '_' + @getRoomId()
      callback lastPlayedIn, false

  @savePlaylists: =>
    if @isCurrentRoomFavorite()
      lastPlayedIn = @getRoomId()
    else
      lastPlayedIn = 'default'
    @updateFavorites (roomId) =>
      @saveRoomPlaylist roomId
      @save 'lastPlayedIn', roomId

  @loadPlaylists: (location, toSave) =>
    identifier = userId + '_' + location
    chrome.storage.sync.get identifier, (data) =>
      active = data[identifier].splice(0, 1)[0]
      for playlist in playlists
        enable = false
        for enabledPlaylist in data[identifier] # Remaining data are enabled playlists.
          if playlist.name == enabledPlaylist
            enable = true
        if enable then playlist.enable() else playlist.disable()

      @savePlaylists() if toSave
      @showIcon()

      activated = playlists.filter(Playlist.isActivated)[0]
      if !activated.enabled
        playlist = @getRandomPlaylist()
        if playlist? then playlist.activate()


  @load: =>
    chrome.storage.sync.get userId, (data) => 
      userData = data[userId] if data[userId]?

      if userData.selections?
        selections = userData.selections

      # Old version compatibility.
      if userData.status? or userData.playlists?
        if userData.status?
          active = userData.status
          delete userData.status
        if userData.playlists?
          savedPlaylists = JSON.parse(userData.playlists)
          for playlist in playlists
            enable = false
            for enabledPlaylist in savedPlaylists
              if playlist.name == enabledPlaylist.n and enabledPlaylist.e
                enable = true
            if enable then playlist.enable() else playlist.disable()
          delete userData.playlists

        @savePlaylists()
        @showIcon()

      else
        if userData.lastPlayedIn?
          lastPlayedIn = userData.lastPlayedIn
        if userData.favorites?
          favorites = userData.favorites
          @updateFavorites (roomId, toSave) =>
            @loadPlaylists roomId, toSave


  @save: (key, value) =>
    userData[key] = value
    data = {}
    data[userId] = userData
    chrome.storage.sync.set data

  class Playlist
    constructor: (@dom) ->
      @name = @dom.children('span.name').text()
      @count = parseInt(@dom.children('span.count').text())
      @enabled = false

      @applyTrigger()

    disable: ->
      @enabled = false
      @dom.fadeTo(FADE_DURATION, FADE_OPACITY)

    enable: ->
      @enabled = true
      @dom.fadeTo(FADE_DURATION, 1)

    toggle: ->
      if @enabled then @disable() else @enable()
      Plugmixer.savePlaylists()

    @isEnabled = (index) ->
      # this refers to filtered objects.
      return this.enabled

    @isActivated = (index) ->
      # this refers to filtered objects.
      return this.dom.children('.activate-button').css('display') == 'block'

    applyTrigger: ->
      @dom.children('span.count').click (event) =>
        @toggle()

    clickDom: ->
      mouseEvent = document.createEvent 'MouseEvents'
      mouseEvent.initMouseEvent 'mouseup', true, true, window,
        1, 0, 0, 0, 0, false, false, false, false, 0, null
      @dom[0].dispatchEvent(mouseEvent)

    activate: ->
      @clickDom()
      $('.activate-button').eq(0).click() # Clicks one button, works for all playlists.
      window.postMessage
        about: 'plugmixer_send_chat',
        message: 'Next playing from ' + @name + '.'
        , '*'