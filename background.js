// Generated by CoffeeScript 1.7.1
chrome.runtime.onMessage.addListener(function(message, sender, sendResponseTo) {
  switch (message) {
    case "plugmixer_inactive_icon":
      chrome.pageAction.setIcon({
        "tabId": sender.tab.id,
        "path": {
          "19": "icon19bw.png",
          "38": "icon38bw.png"
        }
      });
      return chrome.pageAction.show(sender.tab.id);
    case "plugmixer_active_icon":
      chrome.pageAction.setIcon({
        "tabId": sender.tab.id,
        "path": {
          "19": "icon19.png",
          "38": "icon38.png"
        }
      });
      return chrome.pageAction.show(sender.tab.id);
  }
});

chrome.runtime.onInstalled.addListener(function(details) {
  return chrome.storage.sync.get(['status'], function(data) {
    if (data.status == null) {
      return chrome.storage.sync.set({
        'status': true,
        'indicator': 'both'
      });
    }
  });
});

chrome.pageAction.onClicked.addListener(function(tab) {
  return chrome.tabs.sendMessage(tab.id, 'icon_clicked', function(response) {});
});
