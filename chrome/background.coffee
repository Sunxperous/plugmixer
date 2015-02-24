'use strict'

ACTIVE_ICON_19    = 'images/icon19.png'
ACTIVE_ICON_38    = 'images/icon38.png'

chrome.runtime.onMessage.addListener (message, sender, sendResponseTo) ->
  if message == 'plugmixer_show_icon'
    chrome.pageAction.setIcon 
      "tabId": sender.tab.id,
      "path":
        "19": ACTIVE_ICON_19,
        "38": ACTIVE_ICON_38
    chrome.pageAction.show sender.tab.id 
    chrome.pageAction.setTitle 'tabId': sender.tab.id, 'title': 'Plugmixer'
