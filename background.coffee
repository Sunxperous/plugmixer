'use strict'

INACTIVE_ICON_19 = 'images/icon19bw.png'
INACTIVE_ICON_38 = 'images/icon38bw.png'
ACTIVE_ICON_19   = 'images/icon19.png'
ACTIVE_ICON_38   = 'images/icon38.png'

chrome.runtime.onMessage.addListener (message, sender, sendResponseTo) ->
  switch message
    when "plugmixer_inactive_icon"
      chrome.pageAction.setIcon 
        "tabId": sender.tab.id,
        "path":
          "19": INACTIVE_ICON_19,
          "38": INACTIVE_ICON_38
      chrome.pageAction.show(sender.tab.id)
    when "plugmixer_active_icon"
      chrome.pageAction.setIcon 
        "tabId": sender.tab.id,
        "path":
          "19": ACTIVE_ICON_19,
          "38": ACTIVE_ICON_38
      chrome.pageAction.show(sender.tab.id)

chrome.runtime.onInstalled.addListener (details) ->
  chrome.storage.sync.get ['status'], (data) ->
    if !data.status?
      chrome.storage.sync.set
        'status': true

chrome.pageAction.onClicked.addListener (tab) ->
  chrome.tabs.sendMessage tab.id, 'plugmixer_icon_clicked', (response) ->