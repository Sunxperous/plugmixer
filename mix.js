// Displays or alerts user of Plugmixer.
console.log('Mixing of playlists initialized!');

// Event API listener.
API.on(API.DJ_ADVANCE, function(obj) {

  // When the user is the current DJ, activate another playlist.
  if (obj.dj.username === API.getUser().username) {

    //console.log('Activating a random playlist...');

    // Randomizes playlist activation.
    var l = $('#playlist-menu .menu .row').length;
    var x = Math.floor(Math.random() * l);

    // Activates playlist.
    $('#playlist-menu .menu .row').eq(x).trigger("mouseup");
    $('.activate-button').click();

    // Informs user of activated playlist in chat window.
    var name = $('#playlist-menu .menu .row').eq(x).children('.name').text();
    console.log('New playlist [' + name + '] activated!');
    API.chatLog('Next playing from ' + name + '.');
  }
});

