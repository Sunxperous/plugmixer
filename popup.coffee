'use strict'

OPACITY    = '0.3'
SHIFT_LEFT = '-63px'

tabId = null

chrome.tabs.query {active: true, currentWindow: true}, (tabs) ->
  tabId = tabs[0].id
  chrome.pageAction.getTitle {tabId: tabId}, (result) ->
    if result == 'Plugmixer'
      $('.toggle').css('left', SHIFT_LEFT)
      $('.inactive').css('opacity', OPACITY)
    else
      $('.active').css('opacity', OPACITY)

$('#status').click (event) ->
  chrome.tabs.sendMessage tabId, 'plugmixer_toggle_status', (response) ->
    if response == 'plugmixer_make_active'
      $('.inactive').animate {'opacity': OPACITY, 'left': SHIFT_LEFT}
      $('.active').animate {'opacity': '1', 'left': SHIFT_LEFT}
    else
      $('.inactive').animate {'opacity': '1', 'left': '0'}
      $('.active').animate {'opacity': OPACITY, 'left': '0'}
