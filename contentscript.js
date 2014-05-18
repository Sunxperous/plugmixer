// Generated by CoffeeScript 1.7.1
'use strict';
var INITIALIZATION_TIMER, INITIALIZATION_TTL, Plugmixer, ttl, waitForPlaylists;

INITIALIZATION_TIMER = 256;

INITIALIZATION_TTL = 192;

ttl = 0;

waitForPlaylists = function() {
  ttl++;
  if ($('#playlist-menu div.row').length !== 0) {
    return Plugmixer.initialize();
  } else if (ttl <= INITIALIZATION_TTL) {
    console.log('waiting for playlists...');
    return setTimeout(waitForPlaylists, INITIALIZATION_TIMER);
  }
};

waitForPlaylists();

Plugmixer = (function() {
  var Playlist, active, playlists, userId;

  function Plugmixer() {}

  playlists = null;

  active = true;

  userId = null;

  Plugmixer.initialize = function() {
    var inject, playlistsDom;
    playlistsDom = $('#playlist-menu div.row');
    playlists = playlistsDom.map(function(i, pDom) {
      return new Playlist($(pDom));
    });
    inject = document.createElement('script');
    inject.src = chrome.extension.getURL('apimessenger.js');
    (document.head || document.documentElement).appendChild(inject);
    window.addEventListener('message', function() {
      var handler;
      handler = function(event) {
        if ((event.data.about != null) && event.data.about === 'plugmixer_user_info') {
          userId = event.data.userId;
          return window.removeEventListener('message', handler);
        }
      };
      return handler;
    });
    Plugmixer.load();
    window.addEventListener('message', Plugmixer.listenFromMessenger);
    return chrome.runtime.onMessage.addListener(Plugmixer.listenFromBackground);
  };

  Plugmixer.listenFromBackground = function(message, sender, sendResponseTo) {
    if (message === 'plugmixer_icon_clicked') {
      return Plugmixer.toggleStatus();
    }
  };

  Plugmixer.listenFromMessenger = function(event) {
    var playlist;
    if (active && event.data === 'plugmixer_user_playing') {
      playlist = Plugmixer.getRandomPlaylist();
      if (playlist != null) {
        return playlist.activate();
      }
    }
  };

  Plugmixer.showIcon = function() {
    if (active) {
      return chrome.runtime.sendMessage('plugmixer_active_icon');
    } else {
      return chrome.runtime.sendMessage('plugmixer_inactive_icon');
    }
  };

  Plugmixer.toggleStatus = function() {
    active = !active;
    chrome.storage.sync.set({
      'status': active
    });
    return Plugmixer.showIcon();
  };

  Plugmixer.getRandomPlaylist = function() {
    var countSum, playlist, playlistCount, weightedSelect, _i, _j, _len, _len1, _ref, _ref1;
    countSum = 0;
    _ref = playlists.filter(Playlist.isEnabled);
    for (_i = 0, _len = _ref.length; _i < _len; _i++) {
      playlist = _ref[_i];
      countSum += playlist.count;
    }
    playlistCount = playlists.length;
    weightedSelect = Math.floor(Math.random() * countSum) + 1;
    _ref1 = playlists.filter(Playlist.isEnabled);
    for (_j = 0, _len1 = _ref1.length; _j < _len1; _j++) {
      playlist = _ref1[_j];
      if (weightedSelect < playlist.count) {
        return playlist;
      }
      weightedSelect -= playlist.count;
    }
    return null;
  };

  Plugmixer.load = function() {
    return chrome.storage.sync.get(['playlists', 'status'], function(data) {
      var playlist, savedPlaylist, savedPlaylists, _i, _len, _results;
      if (data.status != null) {
        active = data.status;
        Plugmixer.showIcon();
      }
      if (data.playlists != null) {
        console.log(data.playlists);
        savedPlaylists = JSON.parse(data.playlists);
        _results = [];
        for (_i = 0, _len = playlists.length; _i < _len; _i++) {
          playlist = playlists[_i];
          _results.push((function() {
            var _j, _len1, _results1;
            _results1 = [];
            for (_j = 0, _len1 = savedPlaylists.length; _j < _len1; _j++) {
              savedPlaylist = savedPlaylists[_j];
              if (playlist.name === savedPlaylist.name && !savedPlaylist.enabled) {
                _results1.push(playlist.disable());
              } else {
                _results1.push(void 0);
              }
            }
            return _results1;
          })());
        }
        return _results;
      }
    });
  };

  Plugmixer.savePlaylists = function() {
    var playlistsCondensed;
    playlistsCondensed = $.makeArray(playlists).map(function(playlist) {
      return {
        name: playlist.name,
        enabled: playlist.enabled
      };
    });
    playlistsCondensed = JSON.stringify(playlistsCondensed);
    return chrome.storage.sync.set({
      'playlists': playlistsCondensed
    });
  };

  Playlist = (function() {
    var FADE_DURATION, FADE_OPACITY;

    FADE_DURATION = 0.3;

    FADE_OPACITY = 0.4;

    function Playlist(dom) {
      this.dom = dom;
      this.name = this.dom.children('span.name').text();
      this.count = parseInt(this.dom.children('span.count').text());
      this.enabled = true;
      this.applyTrigger();
    }

    Playlist.prototype.disable = function() {
      this.enabled = false;
      return this.dom.fadeTo(FADE_DURATION, FADE_OPACITY);
    };

    Playlist.prototype.enable = function() {
      this.enabled = true;
      return this.dom.fadeTo(FADE_DURATION, 1);
    };

    Playlist.prototype.toggle = function() {
      if (this.enabled) {
        this.disable();
      } else {
        this.enable();
      }
      return Plugmixer.savePlaylists();
    };

    Playlist.isEnabled = function(index) {
      return this.enabled;
    };

    Playlist.prototype.applyTrigger = function() {
      return this.dom.children('span.count').click((function(_this) {
        return function(event) {
          return _this.toggle();
        };
      })(this));
    };

    Playlist.prototype.clickDom = function() {
      var mouseEvent;
      mouseEvent = document.createEvent('MouseEvents');
      mouseEvent.initMouseEvent('mouseup', true, true, window, 1, 0, 0, 0, 0, false, false, false, false, 0, null);
      return this.dom[0].dispatchEvent(mouseEvent);
    };

    Playlist.prototype.activate = function() {
      this.clickDom();
      $('.activate-button').eq(0).click();
      return window.postMessage({
        about: 'plugmixer_send_chat',
        message: 'Next playing from ' + this.name + '.'
      }, '*');
    };

    return Playlist;

  })();

  return Plugmixer;

})();
