console.log('Mixing of playlists initialized!');
API.on(API.DJ_ADVANCE, function(obj) {
  if (obj.dj.username === API.getUser().username) {
    console.log('Activating a random playlist...');
    var l = $('#playlist-menu .menu .row').length;
    var x = Math.floor(Math.random() * l);
    $('#playlist-menu .menu .row').eq(x).trigger("mouseup");
    $('.activate-button').click();
    var name = $('#playlist-menu .menu .row').eq(x).children('.name').text();
    console.log('New playlist [' + name + '] activated!');
    API.chatLog('Next playing from ' + name + '.');
  }
});

