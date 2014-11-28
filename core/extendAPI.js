'use strict';

function extendAPI() {

  if (typeof API === 'undefined' || API === null) return;

  // ===
  // API.getCommunity()
  // ===
  // Returns the current community object.
  API.getCommunity = function() {

    // Returns empty object if not in a community.
    if (! $('#room').is(':visible')) {
      return {};
    }

    var path = function() {
      var pathname = window.location.pathname;
      // If path ends with '/', strip it.
      if (pathname.charAt(pathname.length - 1) === '/') {
        pathname = pathname.slice(0, -1);
      }
      return pathname;
    }();

    var id = path.slice(1); // Strips the front '/'.

    var name = $('#room-name .bar-value').text();

    var description = $('#room-info .description .value').text();

    var welcomeMessage = $('#room-info .welcome .value').text();

    var hostName = $('#room-host .username').text();

    return {
      path: path,
      id: id,
      name: name, 
      description: description,
      welcomeMessage: welcomeMessage,
      hostName: hostName,
    };

  };

  // ===
  // API.getRoom()
  // ===
  // Alias for API.getCommunity().
  API.getRoom = API.getCommunity;

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
