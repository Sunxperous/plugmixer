'use strict'

inject = document.createElement 'script'
inject.src = chrome.extension.getURL 'mix.js'
(document.head || document.documentElement).appendChild inject

window.addEventListener "message", (event) ->
  return if event.source != window

  if event.data.method
    switch event.data.method
      when 'plugmixer_save_playlists'
        chrome.storage.sync.set
          'playlists': event.data.playlists
      when 'plugmixer_save_status'
        chrome.storage.sync.set
          'status': event.data.status
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
