'use strict'

tabId = null

chrome.tabs.query {active: true, currentWindow: true}, (tabs) ->
  tabId = tabs[0].id
  chrome.pageAction.getTitle {tabId: tabId}, (result) ->
    if result == 'Plugmixer'
      $('.toggle').css('left', '-60px')
      $('.inactive').css('opacity', '0.5')
      $('.active').css('opacity', '1')
    else
      $('.toggle').css('left', '0')
      $('.active').css('opacity', '0.5')
      $('.inactive').css('opacity', '1')

$('#status').click (event) ->
  chrome.tabs.sendMessage tabId, 'plugmixer_toggle_status', (response) ->
    console.log response
    if response == 'plugmixer_make_active'
      $('.inactive').animate {'opacity': '0.5', 'left': '-60px'}
      $('.active').animate {'opacity': '1', 'left': '-60px'}
    else
      $('.inactive').animate {'opacity': '1', 'left': '0'}
      $('.active').animate {'opacity': '0.5', 'left': '0'}
