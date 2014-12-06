'use strict'

ACTIVE_ICON_19    = 'images/icon19.png'
ACTIVE_ICON_38    = 'images/icon38.png'
NOTIFY_IF         = '2.0.0'

chrome.runtime.onMessage.addListener (message, sender, sendResponseTo) ->
  if message == 'plugmixer_show_icon'
    chrome.pageAction.setIcon 
      "tabId": sender.tab.id,
      "path":
        "19": ACTIVE_ICON_19,
        "38": ACTIVE_ICON_38
    chrome.pageAction.show sender.tab.id 
    chrome.pageAction.setTitle 'tabId': sender.tab.id, 'title': 'Plugmixer'

chrome.runtime.onInstalled.addListener (details) ->

  if details.previousVersion?
    prev = details.previousVersion.split '.'
    curr = chrome.runtime.getManifest().version.split '.'

    if curr[0] > prev[0] or (curr[0] == prev[0] and curr[1] > prev[1]) or
    chrome.runtime.getManifest().version == NOTIFY_IF

      chrome.storage.sync.set 'updated': true

    # We are updating all the old storage keys.
    timestamp = 1400000000000 # Timestamp @ Wed May 14 2014 00:53:20 GMT+8.
    if chrome.runtime.getManifest().version == '2.0.0'
      chrome.storage.sync.get (items) ->
        Object.keys(items).forEach (itemKey) ->

          if itemKey < timestamp # User id key.
            itemKey_ = itemKey + '_'
            items[itemKey_] = items[itemKey]

            # Update the keys of the user's selections.
            items[itemKey].selections.forEach (selection) ->
              selectionKey = itemKey_ + selection
              items[selectionKey] = items[selection]

              delete items[selection]
              chrome.storage.sync.remove selection

            # Remove old user key.
            delete items[itemKey]
            chrome.storage.sync.remove itemKey

        chrome.storage.sync.set items
