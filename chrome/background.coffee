'use strict'

INACTIVE_ICON_19  = 'images/icon19bw.png'
INACTIVE_ICON_38  = 'images/icon38bw.png'
ACTIVE_ICON_19    = 'images/icon19.png'
ACTIVE_ICON_38    = 'images/icon38.png'
NOTIFY_IF         = '1.2.0'

chrome.runtime.onMessage.addListener (message, sender, sendResponseTo) ->
  switch message
    when "plugmixer_make_inactive"
      chrome.pageAction.setIcon 
        "tabId": sender.tab.id,
        "path":
          "19": INACTIVE_ICON_19,
          "38": INACTIVE_ICON_38
      chrome.pageAction.show sender.tab.id
      chrome.pageAction.setTitle 'tabId': sender.tab.id, 'title': 'Plugmixer (inactive)'
    when "plugmixer_make_active"
      chrome.pageAction.setIcon 
        "tabId": sender.tab.id,
        "path":
          "19": ACTIVE_ICON_19,
          "38": ACTIVE_ICON_38
      chrome.pageAction.show sender.tab.id 
      chrome.pageAction.setTitle 'tabId': sender.tab.id, 'title': 'Plugmixer'

chrome.runtime.onInstalled.addListener (details) ->
  chrome.storage.sync.remove 'indicator'
  if details.previousVersion?
    prev = details.previousVersion.split '.'
    curr = chrome.runtime.getManifest().version.split '.'
    if curr[0] > prev[0] or (curr[0] == prev[0] and curr[1] > prev[1]) or chrome.runtime.getManifest().version == NOTIFY_IF
      chrome.storage.sync.set 'updated': true
