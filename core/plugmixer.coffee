`if (typeof EXTEND_API === 'undefined') { EXTEND_API = 'https://localhost:8080/core/extendAPI.js'; }`
`if (typeof PLUGMIXER_HTML === 'undefined') { PLUGMIXER_HTML = 'https://localhost:8080/core/plugmixer.html'; }`

'use strict'

VERSION = "2.1.9"
HTML_VERSION = "2.1.8"
DATE_OF_BIRTH = new Date(2014, 1, 24)

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
    Room.loadAfter WindowMessageListener, Playlists, Selections
    Sync.loadAfter WindowMessageListener, Playlists
    Youtube.loadAfter Sync
    ApiListener.loadAfter Room

    WindowMessageListener.initialize()
    Interface.initialize()

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
      Storage.load 'room', @id
      # Storage.load 'room', idToUse(User.lastPlayedIn)

    @load: (response) -> # Response is a Room data array.
      if !response? # Non-existing room...
        @active = 1
        Playlists.enableAll()
        @save()
      else # Existing room...
        @active = response.splice(0, 1)[0]
        Playlists.update response

      ga 'plugmixer.set', page: API.getRoom().path, title: API.getRoom().name
      ga 'plugmixer.send', 'pageview'

      Interface.updateStatus()

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
      Storage.save 'room', @id, getStatus()
      # Storage.save 'room', idToUse('default'), getStatus()

      # Temporary workaround - favorites now includes all rooms visited regardless starred or not.
      if User.favorites.indexOf(@id) < 0
        User.favorites.unshift @id
        User.save()

    @toggleActive: ->
      @active = if @active == 1 then 0 else 1
      ga 'plugmixer.send', 'event', 'main', 'click', if @active then 'on' else 'off'
      @save()

    @changedTo: (newRoom) ->
      return if !@id?
      @id = newRoom.id
      Storage.load 'room', @id
      # Storage.load 'room', idToUse(User.lastPlayedIn)


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
            when 'sync' then Sync.load data.response

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

      API.on API.GRAB_UPDATE, (data) ->
        if data.user? and data.user.username == API.getUser().username
          Playlists.refreshIfRequired()

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

    @Effects: class Effects


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

    @getActivated: -> return (playlists.filter (playlist, index) -> return playlist.isActive())[0]

    @all: -> return playlists

    @enableAll: -> playlists.forEach (playlist) -> playlist.enable()

    @getById: (id) ->
      return playlists.filter((playlist) -> return playlist.id.toString() == id.toString())[0]

    @refreshIfRequired: ->
      if (playlists.some (playlist) -> return playlist.dom.parent().length == 0)
        API.getPlaylists (_playlists) =>
          _playlists.forEach (_playlist) ->
            oldPlaylist = playlists.filter((playlist) -> return playlist.id == _playlist.id)[0]
            if oldPlaylist? then oldPlaylist.refresh _playlist
            else playlists.push new Playlist(_playlist)

          playlists.forEach (playlist) ->
            if playlist.dom.parent().length == 0 then playlist.remove()

          Selections.Card.update()

    @playOnly: (playlistNames) ->
      @refreshIfRequired()
      playlists.forEach (playlist) ->
        enable = false
        for playlistName in playlistNames
          if playlist.name == playlistName then enable = true
        if enable then playlist.enable() else playlist.disable()

      if not @getActivated().enabled then @activateAnother()

      Selections.Card.update()

    @update = @playOnly

    @enable: (playlistNames) ->
      @refreshIfRequired()
      playlists.forEach (playlist) ->
        enable = false
        for playlistName in playlistNames
          if playlist.name == playlistName then playlist.enable()

      # if not @getActivated().enabled then @activateAnother() # Don't have to activate another, cause we are enabling more.

      Selections.Card.update()

    @disable: (playlistNames) ->
      @refreshIfRequired()
      playlists.forEach (playlist) ->
        enable = false
        for playlistName in playlistNames
          if playlist.name == playlistName then playlist.disable()

      if not @getActivated().enabled then @activateAnother() # Activate another cause we might disable the current one.

      Selections.Card.update()

    @activateAnother: (playlist) ->
      return if playlist? and playlist != activePlaylist # Do nothing if not the same playlist.
      @activateRandom()

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

    @remove: (playlist) -> playlists.splice playlists.indexOf(playlist), 1

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
        @enabled = false
        @id = playlist.id

        @li = $('#plugmixer-playlist-sample').clone().removeAttr('id').addClass 'plugmixer-playlist'
        @li.children('.plugmixer-playlist-name').text @name
        @li.attr 'id', "plugmixer-playlist-#{playlist.id}"
        @li.click (event) => @sync()

        @registerMouseup()
        if @enabled then @enable() else @disable()

        $('#plugmixer-playlists').append @li

      refresh: (updatedPlaylist) ->
        @dom = updatedPlaylist.$
        @registerMouseup()
        @name = updatedPlaylist.name
        @li.children('.plugmixer-playlist-name').text @name
        if @enabled then @enable() else @disable()

      sync: -> Sync.playlist @id

      timestampToAgo = (timestamp) ->
        if !timestamp? then return 'long ago'
        diff = (Date.now() - timestamp) / 1000      # Difference in seconds.
        if diff < 60                                # Within 60 seconds / 1 minute.
          return 'just'
        else if diff < 60 * 60                      # Within 60 minutes / 1 hour.
          minutes = parseInt(diff / 60)
          return "#{minutes}m ago"
        else if diff < 60 * 60 * 24                 # Within 24 hours / 1 day.
          hours = parseInt(diff / (60 * 60))
          return "#{hours}h ago"
        else                                        # More than 1 day.
          days = parseInt(diff / (60 * 60 * 24))
          return "#{days}d ago"

      updateSyncStatus: (syncStatus) ->
        @li.addClass 'plugmixer-playlist-synced'
        @li.children('.plugmixer-playlist-syncinfo').text timestampToAgo(syncStatus.lastSynced)

      registerMouseup: ->
        @dom.children(SPAN_COUNT).unbind 'mouseup'
        @dom.children(SPAN_COUNT).mouseup (event) => # Mouseup to prevent parent triggers.
          @toggle()
          event.preventDefault()
          event.stopPropagation()

      remove: ->
        @li.remove()
        Playlists.remove @
        Selections.Card.update()
        Room.save()

      count: -> return parseInt(@dom.children(SPAN_COUNT).text())

      disable: ->
        @enabled = false
        @dom.fadeTo FADE_DURATION, FADE_OPACITY
        # @li.fadeTo FADE_DURATION, FADE_OPACITY

      enable: ->
        @enabled = true
        @dom.fadeTo FADE_DURATION, 1
        # @li.fadeTo FADE_DURATION, 1

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
        Selections.Card.update()
        Room.save()

      activate: -> API.activatePlaylist @dom

      isActivating: ->
        return @dom.children(SPINNER).length > 0
      isActive: ->
        return @dom.children(ACTIVATE_BUTTON).children('i.icon').eq(0).hasClass ACTIVE_CLASS


  ###
  # Interface.
  ###
  class Interface extends Component
    DIV_HTML_SRC        = PLUGMIXER_HTML + '?v=' + HTML_VERSION
    CLASS_HIDE          = 'plugmixer-hide'
    CLASS_IN_USE        = 'plugmixer-in-use'
    SCROLL_OFFSET       = 40

    @currentCard = '#plugmixer-main'

    @initialize: ->
      $.get DIV_HTML_SRC, (divHtml) =>
        $('#room').append divHtml
        $('#plugmixer-version').text 'v' + VERSION

        $('#plugmixer-bar').click (event) =>
          if event.target.offsetParent.id == 'plugmixer-status'
            Room.toggleActive()
            @updateStatus()
          else toggleInterface()

        $('.plugmixer-card-link').click (event) =>
          switch $(event.currentTarget).data 'card'
            when 'plugmixer-main' then @switchToCard '#plugmixer-main'
            when 'plugmixer-youtube'
              if Youtube.login
                @switchToCard '#plugmixer-sync'
              else
                @switchToCard '#plugmixer-login'

        currDate = new Date()
        if DATE_OF_BIRTH.getMonth() == currDate.getMonth() and # If February, and
          DATE_OF_BIRTH.getDate() <= currDate.getDate() # after 24th February...
            $('#plugmixer-message').text "plugmixer is #{currDate.getYear() - DATE_OF_BIRTH.getYear()}, yay!"
            $('#plugmixer-message').css 'color', '#f03f20'
            $('#plugmixer-message').click (event) =>
              ga 'plugmixer.send', 'event', 'footer', 'click', 'birthday'
            $('#plugmixer-message').attr 'target', '_blank'
            $('#plugmixer-message').attr 'href', 'https://plugmixer.sunwj.com'
        else if currDate.getMonth() % 2 == 0
          $('#plugmixer-message').text "rate plugmixer"
          $('#plugmixer-message').click (event) =>
            ga 'plugmixer.send', 'event', 'footer', 'click', 'rate'
          $('#plugmixer-message').attr 'target', '_blank'
          $('#plugmixer-message').attr 'href', 'https://chrome.google.com/webstore/detail/plugmixer/bnfboihohdckgijdkplinpflifbbfmhm/reviews'
        else if currDate.getMonth() % 2 == 1
          $('#plugmixer-message').text "share plugmixer"
          $('#plugmixer-message').click (event) =>
            ga 'plugmixer.send', 'event', 'footer', 'click', 'share'
            API.sendChat 'Plugmixer: Playlist management for plug.dj! https://plugmixer.sunwj.com'

        @updateStatus()
        @done()

    @switchToCard = (card) ->
      @currentCard = card
      $('.plugmixer-card').removeClass('plugmixer-flip-in').addClass 'plugmixer-flip-out'
      $(card).removeClass('plugmixer-flip-out').addClass 'plugmixer-flip-in'

    @updateStatus: ->
      $('#plugmixer-logo').toggleClass 'plugmixer-desaturate', !Room.active
      $('#plugmixer-inactive').toggleClass 'show', !Room.active
      $('#plugmixer-active').toggleClass 'show', !!Room.active

    toggleInterface = =>
      $('#plugmixer-expanded').toggleClass CLASS_HIDE
      $('#plugmixer-dropdown-arrow').toggleClass 'plugmixer-rotate'
      $('#plugmixer').toggleClass 'plugmixer-hover'
      if $('.' + CLASS_IN_USE).length > 0
        $('#plugmixer-selections').scrollTop $('.' + CLASS_IN_USE).position().top - SCROLL_OFFSET
      if not $('#plugmixer-expanded').hasClass CLASS_HIDE # If expanding...
        ga 'plugmixer.send', 'event', 'main', 'click', 'expand'
      else
        ga 'plugmixer.send', 'event', 'main', 'click', 'collapse'


  ###
  # Playlist selections management.
  #   Timestamps are used as the key for storage of selections.
  ###
  class Selections extends Component
    list = {}

    @initialize: ->
      Storage.load 'selections', User.id

    @getKeys: -> return Object.keys list

    @getSelection: (timestamp) -> return list[timestamp]

    @load: (response) -> # Response is an object with key-values selectionKey-selections.
      Object.keys(response).forEach (selectionKey) =>
        timestamp = selectionKey.slice selectionKey.indexOf('_') + 1, selectionKey.length
        name = response[selectionKey].splice 0, 1
        list[timestamp] = new Selection(timestamp, name, response[selectionKey])

      Card.initialize()
      @done()

    @add: (name) ->
      timestamp = Date.now().toString()
      selection = Playlists.getEnabledNames()
      list[timestamp] = new Selection(timestamp, name, selection)

      list[timestamp].save()
      list[timestamp].playOnly()
      User.save()

      return list[timestamp]

    class Card
      @initialize: ->
        $('#plugmixer-save-new').click (event) => expandNew()
        $('#plugmixer-selection-cancel').click (event) => collapseNew()
        $('#plugmixer-input').keyup (event) =>
          if event.keyCode == 13 then addNew() # Enter key.
        @update()

      addNew = ->
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
        $('#plugmixer-number').text activePlaylists.length
        Object.keys(list).forEach (timestamp) -> list[timestamp].scan activePlaylists
        collapseNew()

    @Card = Card

    class Selection
      constructor: (@timestamp, @name, @playlists) ->
        @li = $('#plugmixer-selection-sample').clone().removeAttr('id').addClass 'plugmixer-selection'
        @li.children('.plugmixer-selection-name').text @name
        @li.children('.plugmixer-selection-playlists').text @playlists.join(', ')

        @li.click (event) =>
          if event.target.className.match('plugmixer-selection-delete') != null
            ga 'plugmixer.send', 'event', 'group', 'click', 'delete'
            @remove()
          else if event.target.className.match('plugmixer-selection-enable') != null
            ga 'plugmixer.send', 'event', 'group', 'click', 'enable'
            @enable()
          else if event.target.className.match('plugmixer-selection-disable') != null
            ga 'plugmixer.send', 'event', 'group', 'click', 'disable'
            @disable()
          else
            ga 'plugmixer.send', 'event', 'group', 'click', 'use'
            @playOnly()

        $('#plugmixer-new-selection').after @li

      save: ->
        data = @playlists.slice(0)
        data.unshift @name
        Storage.save 'selection', @timestamp, data

      scan: (activePlaylists) ->
        same = $(@playlists).not(activePlaylists).length == 0
        if same then @li.addClass 'plugmixer-in-use' else @li.removeClass 'plugmixer-in-use'

      enable: ->
        Playlists.enable @playlists
        Room.save()
        Card.update()

      disable: ->
        Playlists.disable @playlists
        Room.save()
        Card.update()

      remove: ->
        @li.addClass 'plugmixer-hide'
        delete list[@timestamp]
        User.save()
        Storage.remove 'selection', @timestamp
        setTimeout (=> @li.remove()), 5000

      playOnly: ->
        Playlists.playOnly @playlists
        Room.save()
        Card.update()


  ###
  # Playlist syncing.
  #   Playlist ids are used as the key for storage of synced playlists.
  ###
  class Sync extends Component
    syncedPlaylists = {}

    @initialize: -> Storage.load 'sync', User.id

    @load: (response) -> # Response is object containing synced playlists.
      syncedPlaylists = response || {}
      @refresh()
      @done()

    @save: ->
      Storage.save 'sync', User.id, syncedPlaylists
      @refresh()

    @refresh: ->
      Playlists.all()
        .filter (playlist) -> return Object.keys(syncedPlaylists).indexOf(playlist.id.toString()) > -1
        .forEach (playlist) -> playlist.updateSyncStatus(syncedPlaylists[playlist.id])

    @add: (plugPlaylistId, ytPlaylistId) ->
      syncedPlaylists[plugPlaylistId] =
        youtube: ytPlaylistId
        ignore: []
        lastSynced: null
      @save()
      return syncedPlaylists[plugPlaylistId]

    @hasPlaylist: (plugPlaylistId) -> return Object.keys(syncedPlaylists).indexOf(plugPlaylistId) > -1

    @playlist: (plugPlaylistId) ->
      return if !Youtube.login
      if Object.keys(syncedPlaylists).indexOf(plugPlaylistId.toString()) > -1
        Youtube.sync plugPlaylistId, syncedPlaylists[plugPlaylistId]
      else
        Youtube.newSync plugPlaylistId, Playlists.getById(plugPlaylistId)

    @link: (plugPlaylistId, ytPlaylistId) ->
      if Playlists.getById(plugPlaylistId)?
        if !syncedPlaylists[plugPlaylistId]?
          syncedPlaylists[plugPlaylistId] =
            youtube: ytPlaylistId
            ignore: []
            lastSynced: null
        else
          syncedPlaylists[plugPlaylistId].youtube = ytPlaylistId


  ###
  # YouTube sync.
  ###
  class Youtube extends Component
    OAUTH2_SCOPES = ['https://www.googleapis.com/auth/youtube']
    OAUTH2_CLIENT_ID = null
    @login = false
    @syncing = false

    @initialize: ->
      if YOUTUBE_OAUTH2_CLIENT_ID? then load YOUTUBE_OAUTH2_CLIENT_ID
      else
        $.getJSON 'https://localhost:8080/core/youtube.json', (data) => load data.CLIENT_ID

    load = (clientId) ->
      OAUTH2_CLIENT_ID = clientId
      if not gapi?
        $.getScript 'https://apis.google.com/js/client.js?onload=googleApiClientReady'

    window.googleApiClientReady = -> gapi.auth.init -> window.setTimeout checkAuth, 1

    checkAuth = (immediate = true) ->
      gapi.auth.authorize
        client_id: OAUTH2_CLIENT_ID
        scope: OAUTH2_SCOPES
        immediate: immediate
      , handleAuthResult

      if !immediate
        ga 'plugmixer.send', 'event', 'sync', 'click', 'login-youtube'

    handleAuthResult = (authResult) ->
      if authResult and not authResult.error
        gapi.client.load 'youtube', 'v3', -> readPlaylists()
      else
        $('#plugmixer-youtube-login').click (event) -> checkAuth false

    readPlaylists = (nextPageToken) ->
      extractPlugPlaylistId = (description) ->
        regex = /plug\.dj \((\d+)\)/g
        match = regex.exec(description)
        if match? then return match[1] else return -1

      request = gapi.client.youtube.playlists.list
        part: 'snippet'
        maxResults: 50
        pageToken: nextPageToken
        mine: true
        fields: 'items(id,snippet/description),nextPageToken'
      request.execute (response) ->
        if !response.result? then return console.debug response

        response.result.items.forEach (ytPlaylist) ->
          plugPlaylistId = extractPlugPlaylistId ytPlaylist.snippet.description
          if plugPlaylistId != -1 then Sync.link plugPlaylistId, ytPlaylist.id

        if response.nextPageToken then readPlaylists response.nextPageToken
        else ready()

    ready = =>
      Sync.save()
      @login = true
      Interface.switchToCard '#plugmixer-sync' if Interface.currentCard == '#plugmixer-login'
      @done()

    @setSyncing: (status) ->
      @syncing = status
      if @syncing then # disable
      else #enable

    @newSync: (plugPlaylistId, plugPlaylist) ->
      return if @syncing
      @setSyncing true
      request = gapi.client.youtube.playlists.insert
        part: 'snippet,status'
        resource:
          snippet:
            title: plugPlaylist.name
            description: "#{plugPlaylist.name} from plug.dj (#{plugPlaylistId})"
          status:
            privacyStatus: 'private'
      request.execute (response) =>
        if !response.result? then return console.debug response
        syncedPlaylist = Sync.add plugPlaylistId, response.result.id
        @setSyncing false
        @sync plugPlaylistId, syncedPlaylist

    @sync: (plugPlaylistId, syncedPlaylist) ->
      return if @syncing
      @setSyncing true

      media = []
      youtubePlaylistItems = {}
      totalItemCount = remainingCount = 0

      getYoutubePlaylist = (nextPageToken) ->
        request = gapi.client.youtube.playlistItems.list
          part: 'snippet'
          maxResults: 50
          pageToken: nextPageToken
          playlistId: syncedPlaylist.youtube
          fields: 'items(id,snippet/publishedAt,snippet/resourceId),nextPageToken'
        request.execute (response) ->
          if !response.result? then return console.debug response
          response.result.items.forEach (item) ->
            if item.snippet.resourceId.kind == 'youtube#video'
              videoId = item.snippet.resourceId.videoId
              youtubePlaylistItems[videoId] =
                playlistItemId: item.id
                added: item.snippet.publishedAt

          if response.nextPageToken then getYoutubePlaylist response.nextPageToken
          else
            process()
            runSync()

      process = =>
        videoIds = Object.keys(youtubePlaylistItems)
        media = media.filter (m) ->
          if videoIds.indexOf(m.cid) > -1 # Remove from media and youtubePlaylistItems if common.
            delete youtubePlaylistItems[m.cid]
            return false
          else
            return true

        totalItemCount = media.length + Object.keys(youtubePlaylistItems).length
        ga 'plugmixer.send', 'event', 'sync', 'click', 'youtube', totalItemCount

      runSync = =>
        remainingCount++
        $("#plugmixer-playlist-#{plugPlaylistId}")
          .children('.plugmixer-playlist-syncinfo').text "#{remainingCount}/#{totalItemCount}"

        if media.length <= 0 && Object.keys(youtubePlaylistItems).length <= 0
          $('.plugmixer-playlist').removeClass('plugmixer-playlist-syncing')
          syncedPlaylist.lastSynced = Date.now()
          Sync.save()
          @setSyncing false

        else if Object.keys(youtubePlaylistItems).length > 0
          # Deleting extra items from YouTube. We will add the new items next time.
          videoId = Object.keys(youtubePlaylistItems)[0]
          item = youtubePlaylistItems[videoId]
          request = gapi.client.youtube.playlistItems.delete
            id: item.playlistItemId
          request.execute (response) =>
            delete youtubePlaylistItems[videoId]
            result = response.result
            if !result? then console.debug response # What can go wrong?
            runSync()

        else
          # Sync missing items to YouTube.
          m = media[0]
          request = gapi.client.youtube.playlistItems.insert
            part: 'snippet,contentDetails'
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
            if !response.result? then syncedPlaylist.ignore.push m.id # Unable to add.
            runSync()

      API.getPlaylistMedia plugPlaylistId, (_media) ->
        media = _media.filter (m) ->
          return m.format == 1 and m.cid.length == 11 and syncedPlaylist.ignore.indexOf(m.id) == -1
        getYoutubePlaylist()

        $("#plugmixer-playlist-#{plugPlaylistId}")
          .children('.plugmixer-playlist-syncinfo').text ''
        $("#plugmixer-playlist-#{plugPlaylistId}")
          .removeClass('plugmixer-playlist-synced')
          .addClass('plugmixer-playlist-syncing')


console.log 'Plugmixer loaded!'
Plugmixer.start()

# Google Analytics
if TRACKING_CODE?
  `(function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
   (i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
   m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
   })(window,document,'script','//www.google-analytics.com/analytics.js','ga');
  `
else window.ga = ->
