`if (typeof EXTEND_API === 'undefined') { EXTEND_API = 'https://localhost:8080/core/extendAPI.js'; }`
`if (typeof PLUGMIXER_HTML === 'undefined') { PLUGMIXER_HTML = 'https://localhost:8080/core/plugmixer.html'; }`

'use strict'

VERSION = "2.1.0"
HTML_VERSION = "2.1.0"

class Plugmixer
  INITIALIZATION_TIMEOUT = 512
  PLAYLIST_MENU_DIV_ROW  = '#playlist-menu div.row'

  extendedAPI = false
  @start: =>
    if $? and API? and !extendedAPI
      extendedAPI = true
      $.getScript EXTEND_API

    if $? and API? and $(PLAYLIST_MENU_DIV_ROW).length != 0 and API.getUser().id? and API.extended
      initialize()
    else
      setTimeout @start, INITIALIZATION_TIMEOUT

  initialize = ->
    User.loadAfter WindowMessageListener
    Playlists.loadAfter WindowMessageListener, Interface, User
    Selections.loadAfter WindowMessageListener, Interface, User
    Room.loadAfter WindowMessageListener, Playlists
    ApiListener.loadAfter Room

    WindowMessageListener.initialize()
    Interface.initialize()
    Youtube.preInitialize()

    if TRACKING_CODE?
      ga 'create', TRACKING_CODE, 'auto', name: 'plugmixer'
      ga 'plugmixer.set', 'contentGroup1', 'Plug.dj rooms'
      ga 'plugmixer.set', 'referrer', ''

  ###
  # For loading dependencies of classes.
  ###
  class Component
    @attach: (component) ->
      if !@attachments? then @attachments = []
      @attachments.push component

    @done: ->
      return if !@attachments?
      @attachments.forEach (component) => component.ready @
      @attachments = null

    @loadAfter: (components...) ->
      @after = components
      @after.forEach (component) => component.attach @

    @ready = (component) ->
      index = @after.indexOf component
      if index > -1 then @after.splice index, 1
      if @after.length == 0 then @initialize()


  ###
  # User management.
  ###
  class User extends Component
    @id: null
    @favorites: []
    @lastPlayedIn: 'default' # Assume last played in default room.

    @initialize: ->
      @id = API.getUser().id
      Storage.load 'user', @id

    @load: (response) ->
      @favorites = response.favorites || @favorites
      @lastPlayedIn = response.lastPlayedIn || @lastPlayedIn
      @done()

    @save: ->
      data = {}
      data.favorites = @favorites
      data.selections = Selections.getKeys()
      data.lastPlayedIn = @lastPlayedIn
      Storage.save 'user', @id, data


  ###
  # Room management.
  ###
  class Room extends Component
    @id: null
    @active: 1

    @initialize: ->
      @id = API.getRoom().id
      Storage.load 'room', idToUse(User.lastPlayedIn)

    @load: (response) -> # Response is a Room data array.
      if !response? # Non-existing room...
        @active = 1
        @save()
      else # Existing room...
        @active = response.splice(0, 1)[0]
        Playlists.update response

      ga 'plugmixer.set', page: API.getRoom().path, title: API.getRoom().name
      ga 'plugmixer.send', 'pageview'

      @done()

    getStatus = =>
      status = Playlists.getEnabled().map (playlist) ->
        return playlist.name
      status.unshift @active
      return status

    idToUse = (defaultRoomId = 'default') =>
      if $('#room-bar .favorite').hasClass 'selected'
        User.lastPlayedIn = @id
        if User.favorites.indexOf(@id) < 0
          User.favorites.unshift @id

      else
        User.lastPlayedIn = 'default'
        if User.favorites.indexOf(@id) > -1
          User.favorites.splice User.favorites.indexOf(@id), 1
          Storage.remove 'room', @id

      User.save()
      return User.lastPlayedIn

    @save: ->
      Storage.save 'room', idToUse('default'), getStatus()

    @toggleActive: ->
      @active = if @active == 1 then 0 else 1
      ga 'plugmixer.send', 'event', 'main', 'click', 'status', @active
      @save()

    @changedTo: (newRoom) ->
      return if !@id?
      @id = newRoom.id
      Storage.load 'room', idToUse(User.lastPlayedIn)


  ###
  # Window message listener.
  ###
  class WindowMessageListener extends Component
    @initialize: ->
      window.addEventListener 'message', (event) ->
        try
          data = JSON.parse event.data
        catch e # Return if data is not JSON parsable.
          return false

        return if !data.plugmixer?

        if data.plugmixer == 'response'
          switch data.type
            when 'user' # Should only happen once.
              User.load data.response
            when 'room' then Room.load data.response # Should only happen once.
            when 'selections' then Selections.load data.response
            when 'playlists' then Youtube.update data.response

      @done()


  ###
  # API listener.
  ###
  class ApiListener extends Component
    @initialize: ->
      Helper.TitleText.update()

      Helper.PlaylistRefresh.initialize()

      API.on API.ADVANCE, (data) ->
        Helper.TitleText.update()
        if data.dj? and data.dj.username == API.getUser().username
          Playlists.activateRandom()

      API.on API.ROOM_CHANGE, (oldRoom, newRoom) ->
        Room.changedTo newRoom

      API.on API.PLAYLIST_ACTIVATE, (playlist) ->
        API.chatLog "Next playing from #{playlist.name}"

      @done()


  ###
  # Miscellaneous features.
  ###
  class Helper
    @TitleText: class TitleText
      TITLE_TEXT = '#now-playing-media .bar-value'
      @update: ->
        $(TITLE_TEXT).attr 'title', $(TITLE_TEXT).text() # Hover text.

    @PlaylistRefresh: class PlaylistRefresh
      @initialize: ->
        $(document).on 'click', '#footer',  (event) ->
          Playlists.refreshIfRequired()
          Interface.update()
          Selections.Card.update()

    @Effects: class Effects
      # December 2014: Snow!
      canvas = context = intervalId = null
      intervalCount = 0
      particles = []
      NO_OF_FRAMES    = 180 # 3s, 60fps.
      SIZE            = 6
      MELT_RATE       = SIZE / NO_OF_FRAMES
      Y_START         = 10
      Y_ACC           = 4
      Y_MIN_ACC       = 1
      X_ACC           = 2
      X_MIN_ACC       = -1 # Moving left.
      X_MAX_VELOCITY  = 2
      X_MIN_VELOCITY  = -2
      SNOW_MIN_COUNT  = 20
      SNOW_UPTO_COUNT = 40 - SNOW_MIN_COUNT

      @initialize: ->
        canvas = document.getElementById 'plugmixer-effects'   
        return if not canvas.getContext
        context = canvas.getContext '2d'     

      @reset: ->
        if canvas? and context?
          clearInterval intervalId
          intervalCount = 0

        particles = []
        for i in [1..Math.random() * SNOW_UPTO_COUNT + SNOW_MIN_COUNT]
          particle =
            size: Math.random() * SIZE
            meltRate: MELT_RATE
            x: Math.random() * canvas.width
            xV: Math.random() * X_ACC + X_MIN_ACC
            y: Y_START
            yV: Math.random() * Y_ACC + Y_MIN_ACC
            move: ->
              @xV = Math.min Math.max(@xV + Math.random() * X_ACC + X_MIN_ACC, X_MIN_VELOCITY), X_MAX_VELOCITY
              @x = @x + @xV
              @y = @y + @yV
              @size = Math.max @size - @meltRate, 0
          particles.push particle

      @draw: ->
        return if not context?
        @reset()

        intervalId = setInterval(@play, 1000 / 60)

      clear = ->
        context.clearRect 0, 0, canvas.width, canvas.height

      @play: ->
        clear()
        if ++intervalCount > NO_OF_FRAMES
          clearInterval intervalId
          intervalCount = 0
        particles.forEach (particle) ->
          particle.move()
          context.beginPath()
          context.arc particle.x, particle.y, particle.size, 2 * Math.PI, false
          context.fillStyle = 'white'
          context.fill()
          context.closePath()


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

    @remove: (type, query) ->
      jsonString = JSON.stringify
        plugmixer: 'remove'
        type: type
        id: query
      window.postMessage jsonString, '*'


  ###
  # Playlists management.
  ###
  class Playlists extends Component
    playlists = []
    activePlaylist = null

    @initialize: ->
      API.getPlaylists (_playlists) => # Retrieve id as well.
        playlists = _playlists.map (playlist) ->
          return new Playlist(playlist)

        activePlaylist = @getActivated()
        @done()

    @getEnabled: ->
      return playlists.filter (playlist, index) -> return playlist.enabled

    @getEnabledNames: -> return @getEnabled().map (playlist) -> return playlist.name

    @getActivated: ->
      return (playlists.filter (playlist, index) ->
        return playlist.isActive()
      )[0]

    @all: -> return playlists

    @getById: (id) ->
      return playlists.filter((playlist) -> return playlist.id.toString() == id.toString())[0]

    @refreshIfRequired: ->
      refresh = false
      for playlist in playlists
        # Refresh if any of the playlists no longer have a dom parent.
        if playlist.dom.parent().length == 0 then refresh = true

      if refresh
        playlistNames = @getEnabled().map (playlist) -> return playlist.name
        refreshPlaylists(playlistNames)

    refreshPlaylists = (playlistNames) =>
      API.getPlaylists (_playlists) =>
        playlists = _playlists.map (playlist) ->
          return new Playlist(playlist)
        
        activePlaylist = @getActivated()
        @update(playlistNames)

    @update: (playlistNames) ->
      @refreshIfRequired()
      playlists.forEach (playlist) ->
        enable = false
        for playlistName in playlistNames
          if playlist.name == playlistName then enable = true
        if enable then playlist.enable() else playlist.disable()

      if not @getActivated().enabled
        @activateAnother()

    @activateAnother: (playlist) ->
      return if playlist? and playlist != activePlaylist # Do nothing if not the same playlist.
      @activateRandom() # if !@getActivated().enabled

    @activateRandom: ->
      return if Room.active != 1 # Do nothing if not active.
      @refreshIfRequired()
      playlist = getRandom()
      activePlaylist = playlist
      if playlist? then playlist.activate()

    getRandom = =>
      countSum = 0
      activePlaylists = @getEnabled()
      for playlist in activePlaylists
        countSum += playlist.count()
      weightedSelect = Math.floor(Math.random() * countSum)
      for playlist in activePlaylists
        if weightedSelect < playlist.count()
          return playlist
        weightedSelect -= playlist.count()
      return null

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
        @id = playlist.id

        @dom.children(SPAN_COUNT).mouseup (event) => # Mouseup to prevent parent triggers.
          @toggle()
          event.preventDefault()
          event.stopPropagation();

      count: -> return parseInt(@dom.children(SPAN_COUNT).text())

      disable: ->
        @enabled = false
        @dom.fadeTo(FADE_DURATION, FADE_OPACITY)

      enable: ->
        @enabled = true
        @dom.fadeTo(FADE_DURATION, 1)

      toggle: ->
        if @enabled
          ga 'plugmixer.send', 'event', 'playlist', 'click', 'disable'
          @disable()
          if @isActivating() or @isActive() # Only activate another if this playlist is active.
            Playlists.activateAnother(@)
        else
          ga 'plugmixer.send', 'event', 'playlist', 'click', 'enable'
          @enable()
          if Playlists.getEnabled().length == 1 and !@isActive()
            Playlists.activateRandom()
        Room.save()

      activate: ->
        API.activatePlaylist @dom

      isActivating: ->
        return @dom.children(SPINNER).length > 0
      isActive: ->
        return @dom.children(ACTIVATE_BUTTON).children('i.icon').eq(0).hasClass ACTIVE_CLASS


  ###
  # Interface.
  ###
  class Interface extends Component
    DIV_HTML_SRC        = PLUGMIXER_HTML + '?v=' + HTML_VERSION

    PARENT_DIV          = '#room'
    MAIN_DIV            = '#plugmixer'
    BAR_DIV             = '#plugmixer-bar'
    BAR_LOGO            = '#plugmixer-logo'
    STATUS_DIV_ID       = 'plugmixer-status'
    STATUS_ACTIVE_DIV   = '#plugmixer-active'
    STATUS_INACTIVE_DIV = '#plugmixer-inactive'
    EXPANDED_DIV        = '#plugmixer-expanded'
    HIDE_CLASS          = 'plugmixer-hide'
    DROPDOWN_ARROW_DIV  = '#plugmixer-dropdown-arrow'
    ROTATE_CLASS        = 'plugmixer-rotate'
    NUMBER_DIV          = '#plugmixer-number'
    SELECTIONS_UL       = '#plugmixer-selections'
    LI_SELECTIONS       = 'li.plugmixer-selection'
    SELECTION_CLASS     = 'plugmixer-selection'
    SELECTION_SAMPLE_LI = '#plugmixer-selection-sample'
    IN_USE_CLASS        = 'plugmixer-in-use'
    SCROLL_OFFSET       = 40

    @initialize: ->
      $.get DIV_HTML_SRC, (divHtml) =>
        $(PARENT_DIV).append divHtml
        $('#plugmixer-version').text 'v' + VERSION
        @update()

        $(BAR_DIV).click (event) =>
          if event.target.offsetParent.id == STATUS_DIV_ID
            Room.toggleActive()
            @update()
          else toggleInterface()

        $(PARENT_DIV).on 'click', 'li.plugmixer-playlist', syncPlaylist

        Helper.Effects.initialize()

        $('.plugmixer-card-link').click (event) =>
          switch $(event.currentTarget).data 'card'
            when 'plugmixer-main'
              @switchToCard '#plugmixer-main'
            when 'plugmixer-youtube'
              if Youtube.login
                @switchToCard '#plugmixer-sync'
              else
                @switchToCard '#plugmixer-login'
              @updatePlaylists()

        @done()

    @switchToCard = (card) ->
      $('.plugmixer-card').removeClass('plugmixer-flip-in').addClass 'plugmixer-flip-out'
      $(card).removeClass('plugmixer-flip-out').addClass 'plugmixer-flip-in'

    @update: ->
      updateStatus()
      updateNumber()

    toggleInterface = =>
      @update()
      @updatePlaylists()
      $(EXPANDED_DIV).toggleClass HIDE_CLASS
      $(DROPDOWN_ARROW_DIV).toggleClass ROTATE_CLASS
      $(MAIN_DIV).toggleClass 'plugmixer-hover'
      if $('.' + IN_USE_CLASS).length > 0
        $(SELECTIONS_UL).scrollTop $('.' + IN_USE_CLASS).position().top - SCROLL_OFFSET
      if $('#plugmixer-input').is(':visible')
        Selections.Card.collapseNew()
      if not $(EXPANDED_DIV).hasClass HIDE_CLASS # If expanding...
        Helper.Effects.draw()
        ga 'plugmixer.send', 'event', 'main', 'click', 'expand'
      else
        ga 'plugmixer.send', 'event', 'main', 'click', 'collapse'

    playlistLi = (playlist) ->
      li = $('#plugmixer-playlist-sample').clone().removeAttr('id').addClass 'plugmixer-playlist'
      li.children('.plugmixer-playlist-name').text playlist.name
      li.data 'id', playlist.id.toString()
      li.attr 'id', "plugmixer-playlist-#{playlist.id}"
      return li

    # appendPlaylists = ->
    #   Playlists.afterInitialization ->
    #     Playlists.all().forEach (playlist) ->
    #       $('#plugmixer-playlists').append playlistLi(playlist)

    syncPlaylist = (event) ->
      id = $(event.currentTarget).data 'id'
      Youtube.syncPlaylist id

    timestampToAgo = (timestamp) ->
      diff = (Date.now() - timestamp) / 1000      # Difference in seconds.
      if diff < 60                                # Within 60 seconds / 1 minute.
        return 'just now'
      else if diff < 60 * 60                      # Within 60 minutes / 1 hour.
        minutes = parseInt(diff / 60)
        return "#{minutes} minute#{minutes != 1 ? 's'} ago"
      else if diff < 60 * 60 * 24                 # Within 24 hours / 1 day.
        hours = parseInt(diff / (60 * 60))
        return "#{hours} hour#{hours != 1 ? 's'} ago"
      else                                        # More than 1 day.
        days = parseInt(diff / (60 * 60 * 24))
        return "#{days} day#{days != 1 ? 's'} ago"

    @updatePlaylists: ->
      $('.plugmixer-playlist').each (index) ->
        id = $(this).data 'id'
        playlist = Youtube.getIfSync id
        if playlist?
          $(this).addClass 'plugmixer-playlist-synced'
          $(this).children('.plugmixer-playlist-syncinfo').text timestampToAgo(playlist.lastSynced)
        else
          $(this).removeClass 'plugmixer-playlist-synced'

    updateNumber = -> $(NUMBER_DIV).text Playlists.getEnabled().length

    updateStatus = ->
      if Room.active
        $(BAR_LOGO).removeClass 'plugmixer-desaturate'
        $(STATUS_INACTIVE_DIV).removeClass 'show'
        $(STATUS_ACTIVE_DIV).addClass 'show'
      else
        $(BAR_LOGO).addClass 'plugmixer-desaturate'
        $(STATUS_ACTIVE_DIV).removeClass 'show'
        $(STATUS_INACTIVE_DIV).addClass 'show'


  ###
  # Playlist selections management.
  #   Timestamps are used as the key for storage of selections.
  ###
  class Selections extends Component
    list = {}

    @initialize: ->
      Storage.load 'selections', User.id
      Card.initialize()

    @getKeys: -> return Object.keys list

    @getSelection: (timestamp) -> return list[timestamp]

    @load: (response) -> # Response is an object with key-values selectionKey-selections.
      Object.keys(response).forEach (selectionKey) =>
        timestamp = selectionKey.slice selectionKey.indexOf('_') + 1, selectionKey.length
        name = response[selectionKey].splice 0, 1
        list[timestamp] = new Selection(timestamp, name, response[selectionKey])

      @done()

    @add: (name) ->
      timestamp = Date.now().toString()
      selection = Playlists.getEnabledNames()
      list[timestamp] = new Selection(timestamp, name, selection)

      list[timestamp].save()
      User.save()

      return list[timestamp]

    class Card
      @initialize: ->
        $('#plugmixer-save-new').click (event) => expandNew()
        $('#plugmixer-selection-cancel').click (event) => collapseNew()
        $('#plugmixer-input').keyup (event) =>
          if event.keyCode == 13 then @addNew() # Enter key.

      @addNew: ->
        selection = Selections.add $('#plugmixer-input').val()
        collapseNew()
        ga 'plugmixer.send', 'event', 'group', 'enter'
      collapseNew = ->
        $('#plugmixer-input').blur() # Otherwise the interface will bug out.
        $('#plugmixer-new-selection').addClass 'plugmixer-hide'
        $('#plugmixer-save-new').prop 'disabled', false
      expandNew = ->
        $('#plugmixer-new-selection').removeClass 'plugmixer-hide'
        $('#plugmixer-save-new').prop 'disabled', true
        $('#plugmixer-input').focus()
        $('#plugmixer-input').val ''
        $('#plugmixer-new-selection').children('.plugmixer-selection-playlists')
          .text Playlists.getEnabledNames().join(', ')

      @update: ->
        activePlaylists = Playlists.getEnabledNames()
        Object.keys(list).forEach (timestamp) -> list[timestamp].scan activePlaylists
        collapseNew()
        Interface.update()

    @Card = Card

    class Selection
      constructor: (@timestamp, @name, @playlists) ->
        @li = $('#plugmixer-selection-sample').clone().removeAttr('id').addClass 'plugmixer-selection'
        @li.children('.plugmixer-selection-name').text @name
        @li.children('.plugmixer-selection-playlists').text @playlists.join(', ')

        @li.click (event) =>
          if event.target.className == 'plugmixer-selection-delete'
            @remove()
          else
            @use()

          Card.update()

        $('#plugmixer-new-selection').after @li

      save: ->
        data = @playlists.slice(0)
        data.unshift @name
        Storage.save 'selection', @timestamp, data

      scan: (activePlaylists) ->
        same = $(@playlists).not(activePlaylists).length == 0 and
          $(activePlaylists).not(@playlists).length == 0 # jQuery array comparison.
        if same then @li.addClass 'plugmixer-in-use' else @li.removeClass 'plugmixer-in-use'

      remove: ->
        @li.addClass 'plugmixer-hide'
        delete list[@timestamp]
        User.save()
        Storage.remove 'selection', @timestamp
        setTimeout (=> @li.remove()), 5000
        ga 'plugmixer.send', 'event', 'group', 'click', 'delete'

      use: ->
        Playlists.update @playlists
        Room.save()
        ga 'plugmixer.send', 'event', 'group', 'click', 'use'


  ###
  # YouTube sync.
  ###
  class Youtube
    OAUTH2_SCOPES = ['https://www.googleapis.com/auth/youtube']
    OAUTH2_CLIENT_ID = null
    playlists = {}
    @login = false

    window.googleApiClientReady = ->
      gapi.auth.init ->
        window.setTimeout checkAuth, 1

    checkAuth = (immediate = true) ->
      gapi.auth.authorize
        client_id: OAUTH2_CLIENT_ID
        scope: OAUTH2_SCOPES
        immediate: immediate
      , handleAuthResult

    handleAuthResult = (authResult) ->
      if authResult and not authResult.error
        loadAPIClientInterfaces()
      else
        $('#plugmixer-youtube-login').click (event) ->
          checkAuth(false)

    loadAPIClientInterfaces = ->
      gapi.client.load 'youtube', 'v3', ->
        Youtube.postInitialize()

    # Load client id first, then stored data, then Google API.
    @preInitialize: ->
      if YOUTUBE_OAUTH2_CLIENT_ID?
        OAUTH2_CLIENT_ID = YOUTUBE_OAUTH2_CLIENT_ID
        @initialize()
      else
        $.getJSON 'https://localhost:8080/core/youtube.json', (data) =>
          OAUTH2_CLIENT_ID = data.CLIENT_ID
          @initialize()

    @initialize: ->
      Storage.load 'playlists', User.id

    @update: (response) -> # Response is array of synced playlists.
      playlists = response || {}
      if not gapi?
        $.getScript 'https://apis.google.com/js/client.js?onload=googleApiClientReady'

    @save: ->
      Storage.save 'playlists', User.id, playlists

    @postInitialize: ->
      @login = true
      Interface.switchToCard '#plugmixer-sync'

    getYoutubePlaylistId = (playlist, callback) ->
      if playlists.hasOwnProperty playlist.id
        callback playlists[playlist.id]
      else # Create a YouTube playlist.
        request = gapi.client.youtube.playlists.insert
          part: 'snippet, status'
          resource:
            snippet:
              title: playlist.name
              description: "#{playlist.name} from plug.dj (#{playlist.id})"
            status:
              privacyStatus: 'private'
        request.execute (response) =>
          result = response.result
          if !result? then return console.debug response
          playlists[playlist.id] = 
            youtube: result.id
            ignore: []
            lastSynced: null
          Youtube.save()
          callback playlists[playlist.id]

    @syncPlaylist: (id) ->
      playlist = Playlists.getById id
      getYoutubePlaylistId playlist, (syncedPlaylist) ->
        Sync.run playlist, syncedPlaylist
          
    @getIfSync: (id) ->
      if Object.keys(playlists).indexOf(id) > -1 then return playlists[id] else null

    class Sync
      @syncing = false
      media = []
      youtubePlaylistItems = {}
      playlist = {}
      syncedPlaylist = null

      @run: (_playlist, _syncedPlaylist) ->
        return if @syncing
        @syncing = true
        playlist = _playlist
        syncedPlaylist = _syncedPlaylist
        API.getPlaylistMedia playlist.id, (_media) ->
          media = _media.filter (m) ->
            return m.format == 1 and m.cid.length == 11 and syncedPlaylist.ignore.indexOf(m.id) == -1      
          getYoutubePlaylist _syncedPlaylist

      getYoutubePlaylist = (_syncedPlaylist, _pageToken) ->
        request = gapi.client.youtube.playlistItems.list
          part: 'snippet'
          maxResults: 50
          pageToken: _pageToken
          playlistId: _syncedPlaylist.youtube
          fields: 'items(id,snippet/publishedAt,snippet/resourceId),nextPageToken,prevPageToken'
        request.execute (response) ->
          result = response.result
          if !result? then return console.log response
          result.items.forEach (item) -> 
            if item.snippet.resourceId.kind == 'youtube#video'
              videoId = item.snippet.resourceId.videoId
              youtubePlaylistItems[videoId] =
                playlistItemId: item.id
                added: item.snippet.publishedAt

          if response.nextPageToken
            getYoutubePlaylist _syncedPlaylist, response.nextPageToken
          else
            diff()

      diff = =>
        videoIds = Object.keys(youtubePlaylistItems)
        media = media.filter (m) ->
          index = videoIds.indexOf(m.cid)
          if index > -1
            delete youtubePlaylistItems[m.cid]
            return false
          else
            return true
        $("#plugmixer-playlist-#{playlist.id}")
          .removeClass('plugmixer-playlist-synced')
          .addClass('plugmixer-playlist-syncing')
        sync()

      sync = =>
        $("#plugmixer-playlist-#{playlist.id}")
          .children('.plugmixer-playlist-syncinfo').text "#{media.length}/#{playlist.count()}" 
        if media.length <= 0 && Object.keys(youtubePlaylistItems).length <= 0
          $('.plugmixer-playlist').removeClass('plugmixer-playlist-syncing')
          @syncing = false
          syncedPlaylist.lastSynced = Date.now()
          Youtube.save()
          Interface.updatePlaylists()

        else if Object.keys(youtubePlaylistItems).length > 0
          # Deleting extra items from YouTube. We will add the new items next time.
          videoId = Object.keys(youtubePlaylistItems)[0]
          item = youtubePlaylistItems[videoId]
          request = gapi.client.youtube.playlistItems.delete
            id: item.playlistItemId
          request.execute (response) =>
            delete youtubePlaylistItems[videoId]
            result = response.result
            if !result? then console.log response # What can go wrong?
            sync()

        else
          # Sync missing items to YouTube.
          m = media[0]
          request = gapi.client.youtube.playlistItems.insert
            part: 'snippet, contentDetails'
            resource:
              snippet:
                playlistId: syncedPlaylist.youtube
                resourceId: 
                  kind: "youtube#video"
                  videoId: m.cid
              contentDetails:
                note: "#{m.author} - #{m.title}"
          request.execute (response) =>
            media.splice 0, 1
            result = response.result
            if !result? # Something went wrong,
              syncedPlaylist.ignore.push m.id
            sync()


console.log 'plugmixer.js loaded'
Plugmixer.start()

# Google Analytics
if TRACKING_CODE?
  `
    (function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
    (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
    m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
    })(window,document,'script','//www.google-analytics.com/analytics.js','ga');
  `
else
  window.ga = ->
