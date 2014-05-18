// Generated by CoffeeScript 1.7.1
'use strict';
var ACTIVE_ICON_19, ACTIVE_ICON_38, INACTIVE_ICON_19, INACTIVE_ICON_38;

INACTIVE_ICON_19 = 'images/icon19bw.png';

INACTIVE_ICON_38 = 'images/icon38bw.png';

ACTIVE_ICON_19 = 'images/icon19.png';

ACTIVE_ICON_38 = 'images/icon38.png';

chrome.runtime.onMessage.addListener(function(message, sender, sendResponseTo) {
  switch (message) {
    case "plugmixer_make_inactive":
      chrome.pageAction.setIcon({
        "tabId": sender.tab.id,
        "path": {
          "19": INACTIVE_ICON_19,
          "38": INACTIVE_ICON_38
        }
      });
      chrome.pageAction.show(sender.tab.id);
      return chrome.pageAction.setTitle({
        'tabId': sender.tab.id,
        'title': 'Plugmixer (inactive)'
      });
    case "plugmixer_make_active":
      chrome.pageAction.setIcon({
        "tabId": sender.tab.id,
        "path": {
          "19": ACTIVE_ICON_19,
          "38": ACTIVE_ICON_38
        }
      });
      chrome.pageAction.show(sender.tab.id);
      return chrome.pageAction.setTitle({
        'tabId': sender.tab.id,
        'title': 'Plugmixer'
      });
  }
});

chrome.runtime.onInstalled.addListener(function(details) {});
