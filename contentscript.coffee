'use strict'

inject = document.createElement 'script'
inject.src = chrome.extension.getURL 'mix.js'
(document.head || document.documentElement).appendChild inject

window.addEventListener "message", (event) ->
  return if event.source != window

  if event.data.method
    if event.data.method == 'save'
      chrome.storage.sync.set({'playlists': event.data.playlists})
    else if event.data.method == 'load'
      chrome.storage.sync.get('playlists', (data) ->
        window.postMessage({method: 'load_response', load: data}, '*')
      )
