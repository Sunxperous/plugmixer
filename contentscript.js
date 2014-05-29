// Generated by CoffeeScript 1.7.1
'use strict';
var FADE_DURATION, FADE_OPACITY, INITIALIZATION_TIMER, INITIALIZATION_TTL, Plugmixer, ttl, waitForPlaylists;

INITIALIZATION_TIMER = 256;

INITIALIZATION_TTL = 192;

FADE_DURATION = 0.3;

FADE_OPACITY = 0.4;

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
  var Playlist, active, favorites, lastPlayedIn, playlists, selectionInUse, selections, userData, userId;

  function Plugmixer() {}

  playlists = null;

  active = 1;

  userId = null;

  userData = {};

  favorites = [];

  selections = [];

  selectionInUse = null;

  lastPlayedIn = 'default';

  Plugmixer.initialize = function() {
    var inject, playlistsDom;
    playlistsDom = $('#playlist-menu div.row');
    playlists = playlistsDom.map(function(i, pDom) {
      return new Playlist($(pDom));
    });
    window.addEventListener('message', Plugmixer.listenFromMessenger);
    chrome.runtime.onMessage.addListener(Plugmixer.listenFromBackground);
    inject = document.createElement('script');
    inject.src = chrome.extension.getURL('apimessenger.js');
    (document.head || document.documentElement).appendChild(inject);
    return chrome.storage.sync.get('updated', function(data) {
      if (data.updated) {
        chrome.storage.sync.set({
          'updated': false
        });
        return window.postMessage({
          about: 'plugmixer_send_chat',
          message: 'Plugmixer has been updated! https://chrome.google.com/webstore/detail/plugmixer/bnfboihohdckgijdkplinpflifbbfmhm/details'
        }, '*');
      }
    });
  };

  Plugmixer.listenFromBackground = function(message, sender, sendResponse) {
    var selectionId;
    if (message === 'plugmixer_toggle_status') {
      Plugmixer.toggleStatus();
      return sendResponse(!!active ? 'plugmixer_make_active' : 'plugmixer_make_inactive');
    } else if (message === 'plugmixer_get_selections') {
      return sendResponse({
        'selections': selections,
        'activePlaylists': Plugmixer.getEnabledPlaylists()
      });
    } else if (message.about === 'plugmixer_save_selection') {
      selectionId = Plugmixer.saveSelection(message.name);
      return sendResponse({
        about: 'plugmixer_selection_saved',
        selectionId: selectionId
      });
    } else if (message.about === 'plugmixer_delete_selection') {
      Plugmixer.deleteSelection(message.selectionId);
      return sendResponse('plugmixer_selection_deleted');
    } else if (message.about === 'plugmixer_choose_selection') {
      return Plugmixer.chooseSelection(message.selectionId);
    }
  };

  Plugmixer.listenFromMessenger = function(event) {
    var playlist;
    if (!!active && event.data === 'plugmixer_user_playing') {
      playlist = Plugmixer.getRandomPlaylist();
      if (playlist != null) {
        return playlist.activate();
      }
    } else if ((event.data.about != null) && event.data.about === 'plugmixer_user_info') {
      userId = event.data.userId;
      return Plugmixer.load();
    }
  };

  Plugmixer.showIcon = function() {
    if (!!active) {
      return chrome.runtime.sendMessage('plugmixer_make_active');
    } else {
      return chrome.runtime.sendMessage('plugmixer_make_inactive');
    }
  };

  Plugmixer.toggleStatus = function() {
    active = !!active ? 0 : 1;
    Plugmixer.savePlaylists();
    return Plugmixer.showIcon();
  };

  Plugmixer.getEnabledPlaylists = function() {
    return $.makeArray(playlists.filter(Playlist.isEnabled)).map(function(playlist) {
      return playlist.name;
    });
  };

  Plugmixer.getEnabledPlaylistsUnshift = function(value) {
    var enabledPlaylists;
    enabledPlaylists = Plugmixer.getEnabledPlaylists();
    enabledPlaylists.unshift(value);
    return enabledPlaylists;
  };

  Plugmixer.chooseSelection = function(selectionId) {
    return chrome.storage.sync.get(selectionId, function(data) {
      var enable, enabledPlaylist, playlist, _i, _j, _len, _len1, _ref;
      for (_i = 0, _len = playlists.length; _i < _len; _i++) {
        playlist = playlists[_i];
        enable = false;
        _ref = data[selectionId];
        for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
          enabledPlaylist = _ref[_j];
          if (playlist.name === enabledPlaylist) {
            enable = true;
          }
        }
        if (enable) {
          playlist.enable();
        } else {
          playlist.disable();
        }
      }
      return Plugmixer.savePlaylists();
    });
  };

  Plugmixer.saveSelection = function(name) {
    var selection, selectionId;
    selectionId = Date.now().toString();
    selection = {};
    selection[selectionId] = Plugmixer.getEnabledPlaylistsUnshift(name);
    chrome.storage.sync.set(selection);
    selections.unshift(selectionId);
    Plugmixer.save('selections', selections);
    return selectionId;
  };

  Plugmixer.deleteSelection = function(selectionId) {
    selections.splice(selections.indexOf(selectionId), 1);
    chrome.storage.sync.remove(selectionId);
    return Plugmixer.save('selections', selections);
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
    weightedSelect = Math.floor(Math.random() * countSum);
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

  Plugmixer.getRoomId = function() {
    var id;
    id = window.location.pathname;
    return id.substring(1, id.length - 1);
  };

  Plugmixer.isCurrentRoomFavorite = function() {
    return $('#room-bar .favorite').hasClass('selected');
  };

  Plugmixer.saveRoomPlaylist = function(name) {
    var roomPlaylists;
    roomPlaylists = {};
    roomPlaylists[userId + '_' + name] = Plugmixer.getEnabledPlaylistsUnshift(active);
    return chrome.storage.sync.set(roomPlaylists);
  };

  Plugmixer.updateFavorites = function(callback) {
    if (Plugmixer.isCurrentRoomFavorite()) {
      if (favorites.indexOf(Plugmixer.getRoomId()) === -1) {
        favorites.push(Plugmixer.getRoomId());
        Plugmixer.save('favorites', favorites);
        return callback(lastPlayedIn, true);
      } else {
        return callback(Plugmixer.getRoomId(), false);
      }
    } else {
      if (favorites.indexOf(Plugmixer.getRoomId()) > -1) {
        favorites.splice(favorites.indexOf(Plugmixer.getRoomId()), 1);
        Plugmixer.save('favorites', favorites);
        chrome.storage.sync.remove(userId + '_' + Plugmixer.getRoomId());
      }
      return callback(lastPlayedIn, false);
    }
  };

  Plugmixer.savePlaylists = function() {
    if (Plugmixer.isCurrentRoomFavorite()) {
      lastPlayedIn = Plugmixer.getRoomId();
    } else {
      lastPlayedIn = 'default';
    }
    return Plugmixer.updateFavorites(function(roomId) {
      Plugmixer.saveRoomPlaylist(roomId);
      return Plugmixer.save('lastPlayedIn', roomId);
    });
  };

  Plugmixer.loadPlaylists = function(location, toSave) {
    var identifier;
    identifier = userId + '_' + location;
    return chrome.storage.sync.get(identifier, function(data) {
      var activated, enable, enabledPlaylist, playlist, _i, _j, _len, _len1, _ref;
      active = data[identifier].splice(0, 1)[0];
      for (_i = 0, _len = playlists.length; _i < _len; _i++) {
        playlist = playlists[_i];
        enable = false;
        _ref = data[identifier];
        for (_j = 0, _len1 = _ref.length; _j < _len1; _j++) {
          enabledPlaylist = _ref[_j];
          if (playlist.name === enabledPlaylist) {
            enable = true;
          }
        }
        if (enable) {
          playlist.enable();
        } else {
          playlist.disable();
        }
      }
      if (toSave) {
        Plugmixer.savePlaylists();
      }
      Plugmixer.showIcon();
      activated = playlists.filter(Playlist.isActivated)[0];
      if (!activated.enabled) {
        playlist = Plugmixer.getRandomPlaylist();
        if (playlist != null) {
          return playlist.activate();
        }
      }
    });
  };

  Plugmixer.load = function() {
    return chrome.storage.sync.get(userId, function(data) {
      var enable, enabledPlaylist, playlist, savedPlaylists, _i, _j, _k, _len, _len1, _len2, _results;
      if (data[userId] != null) {
        userData = data[userId];
        if (userData.selections != null) {
          selections = userData.selections;
        }
        if ((userData.status != null) || (userData.playlists != null)) {
          if (userData.status != null) {
            active = userData.status;
            delete userData.status;
          }
          if (userData.playlists != null) {
            savedPlaylists = JSON.parse(userData.playlists);
            for (_i = 0, _len = playlists.length; _i < _len; _i++) {
              playlist = playlists[_i];
              enable = false;
              for (_j = 0, _len1 = savedPlaylists.length; _j < _len1; _j++) {
                enabledPlaylist = savedPlaylists[_j];
                if (playlist.name === enabledPlaylist.n && enabledPlaylist.e) {
                  enable = true;
                }
              }
              if (enable) {
                playlist.enable();
              } else {
                playlist.disable();
              }
            }
            delete userData.playlists;
          }
          Plugmixer.savePlaylists();
          return Plugmixer.showIcon();
        } else {
          if (userData.lastPlayedIn != null) {
            lastPlayedIn = userData.lastPlayedIn;
          }
          if (userData.favorites != null) {
            favorites = userData.favorites;
            return Plugmixer.updateFavorites(function(roomId, toSave) {
              return Plugmixer.loadPlaylists(roomId, toSave);
            });
          }
        }
      } else {
        Plugmixer.showIcon();
        _results = [];
        for (_k = 0, _len2 = playlists.length; _k < _len2; _k++) {
          playlist = playlists[_k];
          _results.push(playlist.enable());
        }
        return _results;
      }
    });
  };

  Plugmixer.save = function(key, value) {
    var data;
    userData[key] = value;
    data = {};
    data[userId] = userData;
    return chrome.storage.sync.set(data);
  };

  Playlist = (function() {
    function Playlist(dom) {
      this.dom = dom;
      this.name = this.dom.children('span.name').text();
      this.count = parseInt(this.dom.children('span.count').text());
      this.enabled = false;
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

    Playlist.isActivated = function(index) {
      return this.dom.children('.activate-button').css('display') === 'block';
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
