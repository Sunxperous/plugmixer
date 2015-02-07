# ![](https://raw.githubusercontent.com/Sunxperous/plugmixer/master/images/icon48.png) [Plugmixer](https://plugmixer.sunwj.com)

## Playlist management for plug.dj!

### To start using Plugmixer, visit [plugmixer.sunwj.com](https://plugmixer.sunwj.com)!

## Setup and development

Plugmixer uses the following npm modules:

1. [coffee-script](https://github.com/jashkenas/coffeescript) for compilation of CoffeeScript,
1. [uglify-js](https://github.com/mishoo/UglifyJS2) to compress and minify JavaScript, and
1. [http-server](https://github.com/nodeapps/http-server) for development.

The CoffeeScript files to be compiled and JavaScript files to be compressed are defined in `build.sh`.

Use `http-server -S` to serve files over HTTPS.

## Extended plug.dj API

The [script `core/extendAPI.js`](core/extendAPI.js) for extending the current plug.dj API is currently hosted [here](https://plugmixer-serve.sunwj.com/extendAPI.js).

### Extended API constants and methods

#### API.getCommunity() / API.getRoom()
Returns the community object, with the following properties:
`path`, `id`, and `isRoom`.

If the current path is `/dashboard` or `/`, then `isRoom` is false.
Else, the object also contains the following properties:
`name`, `description`, `welcomeMessage`, and `hostName`.

#### API.COMMUNITY_CHANGE / API.ROOM_CHANGE
API event constant. This is called when the user changes communities.
It passes the information of the old and new communities to the callback.

```
API.on(API.COMMUNITY_CHANGE, callback);
function callback(oldCommunity, newCommunity) { ... }
```

#### API.getPlaylists()
Returns an array of the user's playlists, each with the following properties:
`name`, `itemCount`, `active` and `$`.
