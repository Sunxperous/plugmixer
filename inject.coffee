inject = document.createElement 'script'
inject.src = chrome.extension.getURL 'mix.js'
(document.head || document.documentElement).appendChild inject
