'use strict'

OPACITY             = '0.3'
SHIFT_LEFT          = '-63px'
ANIMATION_DURATION  = 256

tabId = null
selections = {}
activePlaylists = null

class Selection
  constructor: (@selectionId, storageData, existing) ->
    @playlists = storageData.splice 1, storageData.length - 1
    @dom = $('.template').clone()
    @name = storageData[0]
    @addToList existing

  addToList: (existing) ->
    @dom.children('.name').text @name
    @dom.removeClass 'template'
    @dom.children('.playlists').html playlistsLi @playlists
    if @sameEnabledPlaylists() then @highlight()
    if existing 
      $('#list').append @dom
    else
      $('.template').after @dom
    showAnimation @dom
    @dom.click @selectionId, @clickSelection

  remove: =>
    @dom.remove() # 'Shallow' removal.

  highlight: (solo = false) ->
    if (solo) then $('.selection').removeClass 'inUse'
    @dom.addClass 'inUse'

  clickSelection: (event) =>
    if event.target.className == 'delete' # Deleting selection.
      chrome.tabs.sendMessage tabId, 
        about: 'plugmixer_delete_selection',
        selectionId: event.data
        , (response) =>
          if response == 'plugmixer_selection_deleted'
            hideAnimation @dom, @remove
    else # Choosing selection.
      chrome.tabs.sendMessage tabId,
        about: 'plugmixer_choose_selection',
        selectionId: event.data
      @highlight(true)
      updateActivePlaylists @playlists

  sameEnabledPlaylists: ->
    return $(@playlists).not(activePlaylists).length == 0 and
      $(activePlaylists).not(@playlists).length == 0

showAnimation = (element, callback) ->
  element.animate {'height': 'show', 'padding': 'show', 'opacity': '1'}
    , ANIMATION_DURATION, callback
hideAnimation = (element, callback) ->
  element.animate {'height': 'hide', 'padding': 'hide', 'opacity': '0'}
    , ANIMATION_DURATION, callback

playlistsLi = (playlists) ->
  return playlists.map (playlist) ->
    '<li>' + playlist + '</li>'

updateActivePlaylists = (playlists) ->
  activePlaylists = playlists
  $('.input .playlists').html playlistsLi activePlaylists
  $('#number_selected').text activePlaylists.length

sameEnabledPlaylists = (storageData, activeData) ->
  storageData.splice 0, 1
  return $(storageData).not(activeData).length == 0 and
    $(activeData).not(storageData).length == 0

chrome.tabs.query {active: true, currentWindow: true}, (tabs) ->
  tabId = tabs[0].id
  chrome.pageAction.getTitle {tabId: tabId}, (result) ->
    # Retrieving Plugmixer status.
    if result == 'Plugmixer'
      $('.toggle').css 'left', SHIFT_LEFT
      $('.inactive').css 'opacity', OPACITY
    else
      $('.active').css 'opacity', OPACITY

  # Retrieving current user's playlist group selections.
  chrome.tabs.sendMessage tabId, 'plugmixer_get_selections', (response) ->
    updateActivePlaylists response.activePlaylists
    chrome.storage.sync.get response.selections, (data) ->
      for selectionId in response.selections
        selections[selectionId] = new Selection \
          selectionId, data[selectionId], true

# Toggling Plugmixer status.
$('#status').click (event) ->
  chrome.tabs.sendMessage tabId, 'plugmixer_toggle_status', (response) ->
    if response == 'plugmixer_make_active'
      $('.inactive').animate {'opacity': OPACITY, 'left': SHIFT_LEFT}
      $('.active').animate {'opacity': '1', 'left': SHIFT_LEFT}
    else
      $('.inactive').animate {'opacity': '1', 'left': '0'}
      $('.active').animate {'opacity': OPACITY, 'left': '0'}

# Saving current playlist group selection.
inputting = 0 # 0: click for input, 1: currently on input, 2: pause toggle.
$('#save').click (event) ->
  if inputting == 1
    $('#save').html '+'
    inputting = 2
    hideAnimation $('.input'), ->
      $('#new').val ''
      inputting = 0
  else if inputting == 0
    $('#save').html '&times;'
    inputting = 1
    showAnimation $('.input'), ->
      $('#new').focus()

# Upon entering new playlist group selection.
$('#new').keyup (event) ->
  if inputting == 1 and event.keyCode == 13
    name = $('#new').val()
    if name.length > 0
      chrome.tabs.sendMessage tabId, 
        about: 'plugmixer_save_selection',
        name: name
        , (response) ->
          if response.about == 'plugmixer_selection_saved'
            $('#save').html '+'
            inputting = 2
            hideAnimation $('.input'), ->
              $('#new').val ''
              inputting = 0
              storageData = activePlaylists.slice(0)
              storageData.unshift name
              selections = new Selection \
                response.selectionId, storageData, false

