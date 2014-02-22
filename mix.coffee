class Mixer
  playlists: null
  selectedPlaylist: ->
    for playlist in this.playlists
      if playlist.dom.children('div.activate-button').css('display') == "block"
        return playlist
    return null

  activate: ->
    _this = this
    console.log 'Mixing of playlists initialized!'
    this.loadPlaylists()

    API.off API.DJ_ADVANCE, null # Turns off previous Mixer instances.
    API.on API.DJ_ADVANCE, (obj) ->
      if obj.dj.username == API.getUser().username

        # Randomizes playlist activation.
        _this.selectRandomPlaylist()

  selectPlaylist: (playlist) ->
    playlist.dom.trigger("mouseup")
    $('.activate-button').click() # Can only click all the activate buttons.
    console.log 'New playlist ' + playlist.name + ' activated!'
    API.chatLog 'Next playing from ' + playlist.name + '.'
    return playlist

  selectRandomPlaylist: ->
    countSum = 0
    for playlist in this.playlists
      countSum += playlist.count
    playlistCount = this.playlists.length
    weightedSelect = Math.floor(Math.random() * countSum) + 1
    for playlist in this.playlists
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
        dom: pJq
      }

mixer = new Mixer
mixer.activate()
