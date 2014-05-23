'use strict'

OPACITY    = '0.3'
SHIFT_LEFT = '-63px'

tabId = null

sameEnabledPlaylists = (storageData, activeData) ->
  storageData.splice 0, 1
  return $(storageData).not(activeData).length == 0 and
    $(activeData).not(storageData).length == 0

# Retrieving Plugmixer status.
chrome.tabs.query {active: true, currentWindow: true}, (tabs) ->
  tabId = tabs[0].id
  chrome.pageAction.getTitle {tabId: tabId}, (result) ->
    if result == 'Plugmixer'
      $('.toggle').css 'left', SHIFT_LEFT
      $('.inactive').css 'opacity', OPACITY
    else
      $('.active').css 'opacity', OPACITY

  # Retrieving current user's playlist group selections.
  chrome.tabs.sendMessage tabId, 'plugmixer_get_selections', (info) ->
    chrome.storage.sync.get info.selections, (data) ->
      for selectionId in info.selections
        clone = $('.template').clone()
        clone.children('.name').text data[selectionId][0] # First element is name of selection.
        if sameEnabledPlaylists data[selectionId], info.activePlaylists
          clone.addClass 'inUse'
        clone.removeClass 'template'
        $('#list').append clone
        clone.animate {'height': 'toggle'}
        clone.click selectionId, clickSelection

# Toggling Plugmixer status.
$('#status').click (event) ->
  chrome.tabs.sendMessage tabId, 'plugmixer_toggle_status', (response) ->
    if response == 'plugmixer_make_active'
      $('.inactive').animate {'opacity': OPACITY, 'left': SHIFT_LEFT}
      $('.active').animate {'opacity': '1', 'left': SHIFT_LEFT}
    else
      $('.inactive').animate {'opacity': '1', 'left': '0'}
      $('.active').animate {'opacity': OPACITY, 'left': '0'}

# Clicking a selection.
clickSelection = (event) ->
  if event.target.className == 'delete' # Delete clicked.
    chrome.tabs.sendMessage tabId, 
      about: 'plugmixer_delete_selection',
      selectionId: event.data
      , (response) =>
        if response == 'plugmixer_selection_deleted'
          $(this).animate {'height': 'hide'}
            , 256, (animation, jumpedtoEnd) ->
              $(this).remove()
  else # Choosing selection.
    chrome.tabs.sendMessage tabId,
      about: 'plugmixer_choose_selection',
      selectionId: event.data
    $('.selection').removeClass 'inUse'
    $(this).addClass 'inUse'


# Hover over + to get x.
$('#save').hover ((event) ->
  $('#selections .title').text 'Save current selection')
  , ((event) ->
    $('#selections .title').text 'PLAYLIST GROUPS' if inputting != 1)

# Saving current playlist group selection.
inputting = 0 # 0: click for input, 1: currently on input, 2: pause toggle.
$('#save').click (event) ->
  if inputting == 1
    $('#save').html '+'
    inputting = 2
    $('.input').animate {'height': 'toggle', 'opacity': '0'}
      , 256, (animation, jumpedToEnd) ->
        $('#new').val ''
        inputting = 0
  else if inputting == 0
    $('#save').html '&times;'
    $('#selections .title').text 'Save current selection'
    inputting = 1
    $('.input').animate {'height': 'toggle', 'opacity': '1'}
      , 256, (animation, jumpedToEnd) ->
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
            $('.input').animate {'height': 'toggle'}
              , 256, (animation, jumpedToEnd) ->
                $('#new').val ''
                inputting = 0
                clone = $('.template').clone()
                clone.children('.name').text name
                $('.template').after clone
                clone.removeClass('template').addClass('inUse')
                clone.animate {'height': 'toggle'}
                clone.click response.selectionId, clickSelection

