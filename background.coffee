chrome.runtime.onMessage.addListener (message, sender, sendResponseTo) ->
  switch message
    when "plugmixer_inactive_icon"
      chrome.pageAction.setIcon 
        "tabId": sender.tab.id,
        "path":
          "19": "icon19bw.png",
          "38": "icon38bw.png"
      chrome.pageAction.show(sender.tab.id)
    when "plugmixer_active_icon"
      chrome.pageAction.setIcon 
        "tabId": sender.tab.id,
        "path":
          "19": "icon19.png",
          "38": "icon38.png"
      chrome.pageAction.show(sender.tab.id)

chrome.runtime.onInstalled.addListener (details) ->
  chrome.storage.sync.get ['status'], (data) ->
    if !data.status?
      chrome.storage.sync.set
        'status': true
