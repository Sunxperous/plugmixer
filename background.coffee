chrome.runtime.onMessage.addListener (message, sender, sendResponseTo) ->
  console.log Date.now()
  chrome.pageAction.show(sender.tab.id)