'use strict'

inject = document.createElement 'script'
inject.src = chrome.extension.getURL 'mix.js'
(document.head || document.documentElement).appendChild inject

chrome.runtime.sendMessage("plugmixer_inactive_icon")

chrome.runtime.onMessage.addListener (message, sender, sendResponseTo) ->
  console.log message
  if message == 'icon_clicked'
    window.postMessage({method: 'plugmixer_icon_clicked'}, '*')

window.addEventListener "message", (event) ->
  return if event.source != window

  if event.data.method
    switch event.data.method
      when 'plugmixer_save_playlists'
        chrome.storage.sync.set
          'playlists': event.data.playlists
      when 'plugmixer_status_change'
        chrome.storage.sync.set
          'status': event.data.status
        if event.data.status # Active
          chrome.runtime.sendMessage("plugmixer_active_icon")
        else # Inactive
          chrome.runtime.sendMessage("plugmixer_inactive_icon")
      when 'plugmixer_load_request'
        chrome.storage.sync.get [
          'playlists',
          'status'
          ], (data) ->
            window.postMessage(
              method: 'plugmixer_load_response',
              playlists: data['playlists'],
              status: data['status']
            , '*')
            if data.status # Active
              chrome.runtime.sendMessage("plugmixer_active_icon")
