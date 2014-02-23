class Mixer
  # Needs a reset method.
  # Pick randomly from first few music in activated playlist.

  playlists: null

  displayLabel: ->
    $('#plugmixer').remove()
    mixerDisplay = '<div id="plugmixer"
      style="position: absolute; right: 16px; bottom: 4px;">
      <span style="color: #90ad2f; font-size: 12px">PLUGMIXER</span>
      </div>'
    $('#room').append(mixerDisplay)

  selectedPlaylist: ->
    for playlist in this.playlists
      if playlist.dom.children('div.activate-button').css('display') == "block"
        return playlist
    return null

  addTriggers: ->
    for playlist in this.playlists
      playlist.dom.children('span.count').click playlist, this.togglePlaylistStatus

  togglePlaylistStatus: (event) ->
    playlist = event.data
    playlist.active = !playlist.active
    if playlist.active
      console.log 'Activated ' + playlist.name + '.'
      playlist.dom.fadeTo(0.3, 1)
    else
      console.log 'Deactivated ' + playlist.name + '.'
      playlist.dom.fadeTo(0.3, 0.4)

  activate: ->
    _this = this
    console.log 'Mixing of playlists initialized!'
    this.loadPlaylists()
    this.addTriggers()
    this.displayLabel()

    API.off API.DJ_ADVANCE, null # Turns off previous Mixer instances.
    API.on API.DJ_ADVANCE, (obj) ->
      if obj.dj.username == API.getUser().username

        # Randomizes playlist activation.
        _this.selectRandomPlaylist()

  selectPlaylist: (playlist) ->
    playlist.dom.trigger("mouseup")
    $('.activate-button').click() # Can only click all the activate buttons.
    console.log 'Next playing from ' + playlist.name + '.'
    API.chatLog 'Next playing from ' + playlist.name + '.'
    return playlist

  active: (index) ->
    return this.active

  selectRandomPlaylist: ->
    countSum = 0
    for playlist in this.playlists.filter this.active
      countSum += playlist.count
    playlistCount = this.playlists.length
    weightedSelect = Math.floor(Math.random() * countSum) + 1
    for playlist in this.playlists.filter this.active
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
        active: true
        dom: pJq
      }

mixer = new Mixer
mixer.activate()
