// Generated by CoffeeScript 1.6.3
(function() {
  var inject;

  inject = document.createElement('script');

  inject.src = chrome.extension.getURL('mix.js');

  (document.head || document.documentElement).appendChild(inject);

}).call(this);
