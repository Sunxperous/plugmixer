document.addEventListener 'DOMContentLoaded', ->
  chrome.storage.sync.get
    indicator: 'both'
  , (data) ->
    radios = document.getElementsByName('indicator')
    for radio in radios
      if radio.value == data.indicator
        radio.checked = true
document.getElementById('save').addEventListener 'click', ->
  radios = document.getElementsByName('indicator')
  for radio in radios
    if radio.checked == true
      indicator = radio.value
      chrome.storage.sync.set
        indicator: indicator
        , ->
          document.getElementById('save').innerText = 'Saved'

for label in document.getElementsByTagName('label')
  label.addEventListener 'click', ->
    document.getElementById('save').innerText = 'Save'