class Mixer
  # Needs a reset method.
  # Pick randomly from first few music in activated playlist.

  playlists: null
  active: true

  toggleStatus: (event) ->
    mixer = event.data
    mixer.active = !mixer.active
    if mixer.active
      console.log('Activated Plugmixer.')
      $('#plugmixer_status').children('span').text('Active')
      $('#plugmixer_status').css('background-color', '#90ad2f')
    else # Inactive.
      console.log('Deactivated Plugmixer.')
      $('#plugmixer_status').children('span').text('Inactive')
      $('#plugmixer_status').css('background-color', '#c42e3b')
    mixer.apiEvent()

  mix: (obj) ->
    if obj.dj.username == API.getUser().username
      this.selectRandomPlaylist()

  apiEvent: ->
    if this.active
      API.on(API.DJ_ADVANCE, this.mix, this)
    else # Inactive.
      API.off(API.DJ_ADVANCE, this.mix, this)

  reset: ->
    # displayLabel()
    $('#plugmixer').remove()

    # activate()
    this.active = false
    this.apiEvent() # Turns off previous Mixer instances.

    for playlist in this.playlists
      # addTriggers()
      playlist.dom.children('span.count').off("click", this.togglePlaylistStatus)

      # togglePlaylistStatus()
      playlist.dom.fadeTo(0.3, 1)

  displayLabel: ->
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
    $('#plugmixer_status').click(this, this.toggleStatus)

  selectedPlaylist: ->
    for playlist in this.playlists
      if playlist.dom.children('div.activate-button').css('display') == "block"
        return playlist
    return null

  addTriggers: ->
    for playlist in this.playlists
      playlist.dom.children('span.count').click(playlist, this.togglePlaylistStatus)

  togglePlaylistStatus: (event) ->
    playlist = event.data
    playlist.enabled = !playlist.enabled
    if playlist.enabled
      console.log 'Enabled ' + playlist.name + '.'
      playlist.dom.fadeTo(0.3, 1)
    else
      console.log 'Disabled ' + playlist.name + '.'
      playlist.dom.fadeTo(0.3, 0.4)

  activate: ->
    _this = this
    console.log 'Mixing of playlists initialized!'
    this.loadPlaylists()
    this.addTriggers()
    this.displayLabel()
    this.apiEvent()    

  selectPlaylist: (playlist) ->
    playlist.dom.trigger("mouseup")
    $('.activate-button').click() # Can only click all the activate buttons.
    console.log 'Next playing from ' + playlist.name + '.'
    API.chatLog 'Next playing from ' + playlist.name + '.'
    return playlist

  enabled: (index) ->
    # this refers to filtered objects.
    return this.enabled

  selectRandomPlaylist: ->
    countSum = 0
    for playlist in this.playlists.filter this.enabled
      countSum += playlist.count
    playlistCount = this.playlists.length
    weightedSelect = Math.floor(Math.random() * countSum) + 1
    for playlist in this.playlists.filter this.enabled
      if weightedSelect < playlist.count
        return this.selectPlaylist(playlist)
      weightedSelect -= playlist.count
    null

  loadPlaylists: ->
    playlistsDom = $('#playlist-menu div.row')
    this.playlists = playlistsDom.map (i, pDom) ->
      pJq = $(pDom)
      {
        name: pJq.children('span.name').text()
        count: parseInt(pJq.children('span.count').text())
        enabled: true
        dom: pJq
      }

if (typeof mixer != 'undefined')
  mixer.reset()
mixer = new Mixer
mixer.activate()
