'use strict';

var EXTEND_API_VERSION = '2.2.1';

(function extendAPI() {

  if (typeof(API) === 'undefined' || API === null) return;

  // ===
  // API.getCommunity()
  // API.getRoom() (alias)
  // ===
  // Returns the current community object.
  API.getCommunity = function() {
    var room = {}

    room.path = function() {
      var pathname = window.location.pathname;
      // If path ends with '/', strip it.
      if (pathname.charAt(pathname.length - 1) === '/') {
        pathname = pathname.slice(0, -1);
      }
      return pathname;
    }();

    room.id = room.path.slice(1); // Strips the front '/'.

    if (room.path === '/dashboard' || room.path === '/') {
      room.isRoom = false;
      return room;
    }

    room.isRoom = true;

    room.name = ''; // Unused.

    room.description = ''; // Unused.

    room.welcomeMessage = ''; // Unused.

    room.hostName = ''; // Removed in plug.dj 1.6.1.11924.

    return room;

  };

  API.getRoom = API.getCommunity;

  // ===
  // API.COMMUNITY_CHANGE
  // API.ROOM_CHANGE (alias)
  // ===
  // API event constant.
  // This is called when the user changes communities.
  // It passes the information of the old and new communities.
  // Usage:
  //   API.on(API.COMMUNITY_CHANGE, callback);
  //   function callback(oldCommunity, newCommunity) { ... }
  API.COMMUNITY_CHANGE = 'roomChange';

  API.ROOM_CHANGE = API.COMMUNITY_CHANGE;

  var oldRoom;

  var onRoomChange = function(callback) {
    return function() {
      var room = API.getRoom();

      if (typeof(callback) === 'function') { callback(room); }
    }
  };

  onRoomChange(function(room) {
    oldRoom = room;
  })();

  $(document).click(function(event) {

    if (window.location.pathname !== oldRoom.path || typeof(oldRoom.path) === 'undefined') {
      var newRoom = API.getRoom();

      onRoomChange(function(room) {
        newRoom = room;
        API.trigger(API.ROOM_CHANGE, oldRoom, newRoom);
        oldRoom = newRoom;
      })();
    }
  });


  // ===
  // API.getPlaylists(callback [optional])
  // ===
  // Returns an Array of the user's playlists.
  // Pass in a callback to retrieve an Array of the user's playlists, with id.
  // Usage:
  //   API.getPlaylists(callback);
  //   function callback(playlistsWithId) { ... }
  API.getPlaylists = function(callback) {

    if (typeof(callback) !== 'function') { return getPlaylistsFromDom(); }

    $.get('/_/playlists', function(response) {

      var playlistsWithId = response.data;

      var playlists = getPlaylistsFromDom().map(function(playlist) {
        var indexToSplice;
        playlistsWithId.some(function(playlistWithId, index) {
          if (playlistWithId.name === playlist.name && playlistWithId.count === playlist.itemCount) {
            indexToSplice = index;
            return true;
          }
        });

        var splicedPlaylist = playlistsWithId.splice(indexToSplice, 1)[0];

        playlist.id = splicedPlaylist.id;
        playlist.count = splicedPlaylist.count;

        return playlist;
      });

      callback(playlists);

    });

  };

  function getPlaylistsFromDom() {
    return $.makeArray(
      $('#playlist-menu div.row').map(function(index, playlistDom) { // jQuery map.

        var playlist = {};

        playlist.$ = $(playlistDom);

        playlist.name = playlist.$.children('span.name').text();

        var itemCountText = playlist.$.children('span.count').text();
        playlist.itemCount = parseInt(itemCountText.substr(1, itemCountText.length - 2));

        playlist.active = playlist.$.children('.activate-button')
          .children('i.icon-playlist').eq(0).hasClass('active');

        return playlist;

      })
    );
  }


  // ===
  // API.getActivePlaylist()
  // ===
  // Returns the playlist that is currently active.
  API.getActivePlaylist = function() {
    return getPlaylistsFromDom().filter(function(playlist) {
      return playlist.active;
    })[0];
  };


  // ===
  // API.activatePlaylist(obj)
  // ===
  // Activates the playlist object that is passed in.
  // Also accepts a integer which will correspond to the index of playlists,
  // or a string which will activate the first playlist with the same name.
  API.activatePlaylist = function(obj) {
    var jQ = null;
    var playlists = getPlaylistsFromDom();

    // Playlist object.
    if (typeof(obj.$) !== 'undefined' && obj.$ !== null && obj.$ instanceof jQuery) {
      jQ = obj.$;
    }

    // jQuery object.
    else if (obj instanceof jQuery) {
      jQ = obj;
    }

    // String object: name of playlist.
    else if (typeof(obj) === 'string') {
      var sameName = playlists.filter(function(playlist) {
        return playlist.name === obj;
      });
      if (sameName.length > 0) { jQ = sameName[0].$; }
    }

    // Number object: index of playlist.
    else if (obj > 0 && obj < playlists.length && parseInt(obj) === obj) {
      jQ = playlists[obj].$;
    }

    if (jQ === null) { throw new Error('There is no such playlist.'); }
    if (jQ.children('.activate-button').length <= 0) { throw new Error('Not a playlist jQuery object.'); }

    // Clicking the playlist's dom row.
    var mouseEvent = document.createEvent('MouseEvents');
    mouseEvent.initMouseEvent('mouseup', true, true, window,
      1, 0, 0, 0, 0, false, false, false, false, 0, null);
    jQ[0].dispatchEvent(mouseEvent);

    $('#playlist-activate-button').click();
  };


  // ===
  // API.PLAYLIST_ACTIVATE
  // ===
  // API event constant.
  // This is called when a playlist is activated.
  // It passes the information of the activated playlist.
  // Usage:
  //   API.on(API.PLAYLIST_ACTIVATE, callback);
  //   function callback(playlist) { ... }
  API.PLAYLIST_ACTIVATE = 'playlistActivate';

  var onPlaylistActivate = function(playlistDom, tries) {
    tries = tries || 0;

    return function() {

      if (playlistDom.children('.spinner').length > 0 && tries < 100) { // 10000ms = 10s.
        setTimeout(onPlaylistActivate(playlistDom, tries + 1), 100);
      }

      else if (playlistDom.find('.active').length > 0) {
        API.trigger(API.PLAYLIST_ACTIVATE, API.getActivePlaylist());
      }

    }
  };

  $(document).on('click', '#playlist-activate-button', function(event) {
    onPlaylistActivate($('.row.selected'))();
  });


  // ===
  // API.getPlaylistMedia(id, callback)
  // ===
  // Retrieves the media items in a playlist.
  API.getPlaylistMedia = function(id, callback) {
    if (typeof(callback) !== 'function') { return; }

    if (typeof(id) !== 'number' && (typeof(id) !== 'string' || id.length > 0)) {
      return callback([]);
    }
    $.get('/_/playlists/' + id + '/media', function(data) {
      callback(data.data);
    });
  };


  API.extended = true;

}).call(this);
