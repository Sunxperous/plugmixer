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
  active = true
  userId = null
  userData = {}
  selections = []
  selectionInUse = null

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
      sendResponse(if active then 'plugmixer_make_active' else 'plugmixer_make_inactive')
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
    if active and event.data == 'plugmixer_user_playing'
      playlist = @getRandomPlaylist()
      if playlist? then playlist.activate()
    else if event.data.about? and event.data.about == 'plugmixer_user_info'
      userId = event.data.userId
      @load() # Ready to load from storage.

  @showIcon: =>
    if active # Active
      chrome.runtime.sendMessage('plugmixer_make_active')
    else # Inactive
      chrome.runtime.sendMessage('plugmixer_make_inactive')

  @toggleStatus: =>
    active = !active
    @save 'status', if active then 1 else 0
    @showIcon()

  @getEnabledPlaylists: =>
    return $.makeArray(playlists.filter(Playlist.isEnabled)).map (playlist) =>
      playlist.name

  @chooseSelection: (selectionId) =>
    chrome.storage.sync.get selectionId, (data) =>
      for playlist in playlists
        playlist.disable()
        for enabledPlaylist in data[selectionId]
          if playlist.name == enabledPlaylist
            playlist.enable()
      @savePlaylists()

  @saveSelection: (name) =>
    selectionId = Date.now().toString()
    selection = {}
    enabledPlaylists = @getEnabledPlaylists()
    enabledPlaylists.unshift name
    selection[selectionId] = enabledPlaylists
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
    weightedSelect = Math.floor(Math.random() * countSum) + 1
    for playlist in playlists.filter Playlist.isEnabled
      if weightedSelect < playlist.count
        return playlist
      weightedSelect -= playlist.count
    null

  @load: =>
    chrome.storage.sync.get ['playlists', 'status', userId], (data) => # Old version compatibility.
      if data.playlists? and data.status? and !data[userId]? # Old data without new data...
        # Old playlists:
        savedPlaylists = JSON.parse(data.playlists)
        for playlist in playlists
          for savedPlaylist in savedPlaylists
            if playlist.name == savedPlaylist.name && !savedPlaylist.enabled
              playlist.disable()
        @savePlaylists()

        # Old status:
        active = data.status
        @save 'status', if active then 1 else 0

        chrome.storage.sync.remove ['playlists', 'status']

      else
        userData = data[userId] if data[userId]?
        if userData.status?
          active = !!userData.status # Converts 0/1 to false/true.
        if userData.playlists?
          savedPlaylists = JSON.parse(userData.playlists)
          for playlist in playlists
            for savedPlaylist in savedPlaylists
              if playlist.name == savedPlaylist.n && !savedPlaylist.e # n=name; e=enabled.
                playlist.disable()
        if userData.selections?
          selections = userData.selections

      @showIcon()

  @save: (key, value) =>
    userData[key] = value
    data = {}
    data[userId] = userData
    chrome.storage.sync.set data

  @savePlaylists: =>
    playlistsCondensed = $.makeArray(playlists).map (playlist) ->
      return { # n=name; e=enabled.
        n: playlist.name,
        e: playlist.enabled
      }
    playlistsCondensed = JSON.stringify(playlistsCondensed)
    @save 'playlists', playlistsCondensed

  class Playlist

    constructor: (@dom) ->
      @name = @dom.children('span.name').text()
      @count = parseInt(@dom.children('span.count').text())
      @enabled = true

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