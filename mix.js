// Generated by CoffeeScript 1.7.1
'use strict';
var Plugmixer, ttl, waitForAPI;

Plugmixer = (function() {
  var Playlist, active, indicator, playlists;

  function Plugmixer() {}

  Plugmixer.INITIALIZATION_TIMER = 256;

  Plugmixer.INITIALIZATION_TTL = 192;

  playlists = null;

  active = false;

  indicator = '<div id="plugmixer" style="position: absolute; right: 6px; bottom: 2px; font-size: 11px;"> <div style="display: inline-block; background-color: #282c35; padding: 1px 8px; border-radius: 3px 0 0 3px; margin-right: -4px;"> <span>PLUGMIXER</span> </div> <div id="plugmixer_status" style="display: inline-block; padding: 1px 4px; background-color: #90ad2f; border-radius: 0 3px 3px 0; font-weight:600; letter-spacing:0.05em; width:60px; text-align:center; cursor: pointer;"> <span>Active</span> </div> </div>';

  Plugmixer.initialize = function() {
    Plugmixer.readPlaylists();
    Plugmixer.loadFromStorage();
    Plugmixer.displayIndicator();
    return API.on(API.DJ_ADVANCE, Plugmixer.mix);
  };

  Plugmixer.saveStatus = function() {
    return window.postMessage({
      method: 'plugmixer_status_change',
      status: active
    }, '*');
  };

  Plugmixer.toggleStatus = function(event) {
    active = !active;
    Plugmixer.saveStatus();
    if (active) {
      $('#plugmixer_status').children('span').text('Active');
      return $('#plugmixer_status').css('background-color', '#90ad2f');
    } else {
      $('#plugmixer_status').children('span').text('Inactive');
      return $('#plugmixer_status').css('background-color', '#c42e3b');
    }
  };

  Plugmixer.mix = function(obj) {
    var playlist;
    if (obj.dj.username === API.getUser().username && active) {
      playlist = Plugmixer.getRandomPlaylist();
      if (playlist != null) {
        return playlist.activate();
      }
    }
  };

  Plugmixer.displayIndicator = function() {
    $('#room').append(indicator);
    return $('#plugmixer_status').click(Plugmixer, Plugmixer.toggleStatus);
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

  Plugmixer.readPlaylists = function() {
    var playlistsDom;
    playlistsDom = $('#playlist-menu div.row');
    return playlists = playlistsDom.map(function(i, pDom) {
      return new Playlist($(pDom));
    });
  };

  Plugmixer.loadFromStorage = function() {
    window.postMessage({
      method: 'plugmixer_load_request'
    }, '*');
    return window.addEventListener("message", function(event) {
      var playlist, savedPlaylist, savedPlaylists, _i, _j, _len, _len1;
      if (event.source !== window) {
        return;
      }
      if (event.data.method === 'plugmixer_load_response' && event.data) {
        if (event.data.playlists != null) {
          savedPlaylists = JSON.parse(event.data.playlists);
          for (_i = 0, _len = playlists.length; _i < _len; _i++) {
            playlist = playlists[_i];
            for (_j = 0, _len1 = savedPlaylists.length; _j < _len1; _j++) {
              savedPlaylist = savedPlaylists[_j];
              if (playlist.name === savedPlaylist.name && !savedPlaylist.enabled) {
                playlist.disable();
              }
            }
          }
        }
        if ((event.data.status == null) || active !== event.data.status) {
          return Plugmixer.toggleStatus();
        }
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
    window.postMessage({
      method: 'plugmixer_save_playlists',
      playlists: playlistsCondensed
    }, '*');
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

    Playlist.prototype.activate = function() {
      this.dom.trigger("mouseup");
      $('.activate-button').eq(0).click();
      return API.chatLog('Next playing from ' + this.name + '.');
    };

    return Playlist;

  })();

  return Plugmixer;

})();

ttl = 0;

waitForAPI = function() {
  ttl++;
  if ((typeof $ !== "undefined" && $ !== null) && $('#playlist-menu div.row').length !== 0) {
    return Plugmixer.initialize();
  } else if (ttl <= Plugmixer.INITIALIZATION_TTL) {
    console.log("waiting for playlists...");
    return setTimeout(waitForAPI, Plugmixer.INITIALIZATION_TIMER);
  }
};

waitForAPI();
