'use strict'

class Plugmixer
  @INITIALIZATION_TIMEOUT = 256

  playlists = null
  active = true

  @initialize: =>
    @readPlaylists()
    @loadFromStorage()
    @displayLabel()
    API.on(API.DJ_ADVANCE, @mix) 

  @saveStatus: =>
    window.postMessage(
      method: 'plugmixer_save_status',
      status: active
    , '*')

  @toggleStatus: (event) =>
    active = !active
    @saveStatus()
    if active
      $('#plugmixer_status').children('span').text('Active')
      $('#plugmixer_status').css('background-color', '#90ad2f')
    else # Inactive.
      $('#plugmixer_status').children('span').text('Inactive')
      $('#plugmixer_status').css('background-color', '#c42e3b')

  @mix: (obj) =>
    if obj.dj.username == API.getUser().username and active
      playlist = @getRandomPlaylist()
      if playlist? then playlist.activate()

  @displayLabel = =>
    mixerDisplay = '<div id="plugmixer"
      style="position: absolute; right: 6px; bottom: 2px; font-size: 11px;">
        <div style="display: inline-block; background-color: #282c35; padding: 1px 8px; border-radius: 3px 0 0 3px; margin-right: -4px;">
          <span>PLUGMIXER</span>
        </div>
        <div id="plugmixer_status" style="display: inline-block; padding: 1px 4px; background-color: #90ad2f; border-radius: 0 3px 3px 0;
        font-weight:600; letter-spacing:0.05em; width:60px; text-align:center; cursor: pointer;">
          <span>Active</span>
        </div>
      </div>'
    $('#room').append(mixerDisplay)
    $('#plugmixer_status').click(@, @toggleStatus)

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

  @readPlaylists: =>
    playlistsDom = $('#playlist-menu div.row')
    playlists = playlistsDom.map (i, pDom) ->
      new Playlist($(pDom))

  @loadFromStorage: =>
    window.postMessage({method: 'plugmixer_load_request'}, '*')
    window.addEventListener "message", (event) =>
      return if event.source != window

      if event.data.method == 'plugmixer_load_response' && event.data
        if event.data.playlists?
          savedPlaylists = JSON.parse(event.data.playlists)
          for playlist in playlists
            for savedPlaylist in savedPlaylists
              if playlist.name == savedPlaylist.name && !savedPlaylist.enabled
                playlist.disable()
        if event.data.status?
          if active != event.data.status
            @toggleStatus()

  @savePlaylists: =>
    playlistsCondensed = $.makeArray(playlists).map (playlist) ->
      return {
        name: playlist.name,
        enabled: playlist.enabled
      }
    playlistsCondensed = JSON.stringify(playlistsCondensed)
    window.postMessage(
      method: 'plugmixer_save_playlists',
      playlists: playlistsCondensed
    , '*')
    return


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

    activate: ->
      @dom.trigger("mouseup")
      $('.activate-button').eq(0).click() # Clicks one button, works for all playlists.
      API.chatLog 'Next playing from ' + @name + '.'

waitForAPI = ->
  if $? && $('#playlist-menu div.row').length != 0
    Plugmixer.initialize()
  else
    setTimeout waitForAPI, Plugmixer.INITIALIZATION_TIMEOUT

waitForAPI()
