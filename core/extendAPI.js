'use strict';

function extendAPI() {

  if (typeof API === 'undefined' || API === null) return;

  // ===
  // API.getCommunity()
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

    room.name = $('#room-name .bar-value').text();

    room.description = $('#room-info .description .value').text();

    room.welcomeMessage = $('#room-info .welcome .value').text();

    room.hostName = $('#room-host .username').text();

    return room;

  };

  // ===
  // API.getRoom()
  // ===
  // Alias for API.getCommunity().
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
  API.COMMUNITY_CHANGE = 'roomChange'

  API.ROOM_CHANGE = 'roomChange'

  var oldRoom;

  var ensureRoomInformation = function(callback) {
    return function() {
      var room = API.getRoom();

      if (room.isRoom && (room.hostName.length === 0
        || room.hostName === '(waiting for host to login)')) {
        
        setTimeout(ensureRoomInformation(callback), 128); 

      }

      else if (typeof(callback) === 'function') { callback(room); }      
    }
  }
  ensureRoomInformation(function(room) {
    oldRoom = room;
  })();

  $(document).click(function(event) {

    if (window.location.pathname != oldRoom.path || typeof oldRoom.path === 'undefined') {
      var newRoom = API.getRoom();

      ensureRoomInformation(function(room) {
        newRoom = room;

        API.trigger(API.ROOM_CHANGE, oldRoom, newRoom);

        oldRoom = newRoom;
      })();
    }
  });


  // ===
  // API.getPlaylists()
  // ===
  // Returns an Array of the user's playlists.
  API.getPlaylists = function() {

    var playlistsDom = $('#playlist-menu div.row');

    var playlists = $.makeArray(playlistsDom.map(function(index, playlistDom) { // jQuery map.

      var playlistJq = $(playlistDom);

      var name = playlistJq.children('span.name').text();

      var itemCount = parseInt(playlistJq.children('span.count').text());

      var active = playlistJq.children('.activate-button')
        .children('i.icon').eq(0).hasClass('icon-active-active');

      return {
        name: name,
        itemCount: itemCount,
        active: active,
        $: playlistJq,
      };

    }));

    return playlists;

  };

  API.extended = true;
}

extendAPI();
