'use strict'

INITIALIZATION_TIMER = 256
INITIALIZATION_TTL   = 192

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

  @initialize: =>
    # Read playlists.
    playlistsDom = $('#playlist-menu div.row')
    playlists = playlistsDom.map (i, pDom) ->
      new Playlist($(pDom))

    # Inject apimessenger.js.
    inject = document.createElement 'script'
    inject.src = chrome.extension.getURL 'apimessenger.js'
    (document.head || document.documentElement).appendChild inject

    # Retrieve user id.
    window.addEventListener 'message', =>
      handler = (event) =>
        if event.data.about? and event.data.about == 'plugmixer_user_info'
          userId = event.data.userId
          window.removeEventListener 'message', handler
      return handler
    
    @load()

    window.addEventListener 'message', @listenFromMessenger
    chrome.runtime.onMessage.addListener @listenFromBackground

  @listenFromBackground: (message, sender, sendResponseTo) =>
    if message == 'plugmixer_icon_clicked'
      @toggleStatus()

  @listenFromMessenger: (event) =>
    if active and event.data == 'plugmixer_user_playing'
      playlist = @getRandomPlaylist()
      if playlist? then playlist.activate()

  @showIcon: =>
    if active # Active
      chrome.runtime.sendMessage('plugmixer_active_icon')
    else # Inactive
      chrome.runtime.sendMessage('plugmixer_inactive_icon')

  @toggleStatus: =>
    active = !active
    chrome.storage.sync.set 'status': active
    @showIcon()

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
    chrome.storage.sync.get ['playlists', 'status'], (data) =>
      if data.status?
        active = data.status
        @showIcon()
      if data.playlists?
        console.log data.playlists
        savedPlaylists = JSON.parse(data.playlists)
        for playlist in playlists
          for savedPlaylist in savedPlaylists
            if playlist.name == savedPlaylist.name && !savedPlaylist.enabled
              playlist.disable()  

  @savePlaylists: =>
    playlistsCondensed = $.makeArray(playlists).map (playlist) ->
      return {
        name: playlist.name,
        enabled: playlist.enabled
      }
    playlistsCondensed = JSON.stringify(playlistsCondensed)
    chrome.storage.sync.set 'playlists': playlistsCondensed

  class Playlist
    FADE_DURATION = 0.3
    FADE_OPACITY = 0.4

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