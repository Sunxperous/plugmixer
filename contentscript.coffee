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

    # Update message.
    chrome.storage.sync.get 'updated', (data) ->
      if data.updated
        chrome.storage.sync.set 'updated': false
        window.postMessage
          about: 'plugmixer_send_chat',
          message: 'Plugmixer has been updated! https://chrome.google.com/webstore/detail/plugmixer/bnfboihohdckgijdkplinpflifbbfmhm/details'
          , '*'

  @refreshIfRequired: =>
    refresh = true
    for playlist in playlists
      if playlist.dom.parent().length != 0 then refresh = false
    # Read playlists.
    if refresh
      playlistsDom = $('#playlist-menu div.row')
      refreshedPlaylists = playlistsDom.map (i, pDom) ->
        new Playlist($(pDom))
      for refreshedPlaylist in refreshedPlaylists
        enable = false
        for playlist in playlists
          if refreshedPlaylist.name == playlist.name
            enable = playlist.enabled
        if enable then refreshedPlaylist.enable() else refreshedPlaylist.disable()
      playlists = refreshedPlaylists

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
      @refreshIfRequired()
      @activateRandomPlaylist()
    else if event.data.about? and event.data.about == 'plugmixer_user_info'
      userId = event.data.userId
      @load() # Ready to load from storage.

  @activateAnotherIfNotEnabled: =>
      # If currently activated playlist is not part of selection...
      activated = playlists.filter(Playlist.isActivated)[0]
      @activateRandomPlaylist() if !activated.enabled

  @activateRandomPlaylist: =>
    playlist = @getRandomPlaylist()
    if playlist? then playlist.activate()

  @numPlaylistsEnabled: =>
    return playlists.filter(Playlist.isEnabled).length

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

      @activateAnotherIfNotEnabled()

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
        callback lastPlayedIn, true # Loads lastPlayedIn then save, or saves roomId.

      else callback @getRoomId(), false # Loads or saves roomId.

    else # Not a favorite...

      if favorites.indexOf(@getRoomId()) > -1 # But listed as favorite.
        favorites.splice favorites.indexOf(@getRoomId()), 1
        @save 'favorites', favorites
        chrome.storage.sync.remove userId + '_' + @getRoomId()

      callback lastPlayedIn, false # Loads lastPlayedIn or saves default.

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
      @showIcon() # Activity determined after load.

      @activateAnotherIfNotEnabled()

  @load: =>
    chrome.storage.sync.get userId, (data) =>
      if data[userId]?
        userData = data[userId]

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

        # New storage version.
        else
          if userData.lastPlayedIn?
            lastPlayedIn = userData.lastPlayedIn
          if userData.favorites?
            favorites = userData.favorites
          @updateFavorites (roomId, toSave) =>
            @loadPlaylists roomId, toSave

      # New user.       
      else 
        @showIcon()
        for playlist in playlists
          playlist.enable()


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
      if @enabled
        @disable()
        if @dom.children('.activate-button').children('i.icon').eq(0).hasClass 'icon-active-selected' # Is currently activated...
          Plugmixer.activateRandomPlaylist()
      else
        @enable()
        @activate() if Plugmixer.numPlaylistsEnabled() == 1
      Plugmixer.savePlaylists()

    @isEnabled = (index) ->
      # this refers to filtered objects.
      return this.enabled

    @isActivated = (index) ->
      # this refers to filtered objects.
      return this.dom.children('.activate-button').children('i.icon').eq(0).hasClass 'icon-active-selected'

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