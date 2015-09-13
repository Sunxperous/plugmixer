# Extended plug.dj API

The [script `core/extendAPI.js`](core/extendAPI.js) for extending the current plug.dj API is currently hosted [here](https://plugmixer-serve.sunwj.com/extendAPI.js).

## Extended API constants and methods

### API.getCommunity() / API.getRoom()
Returns the community object, with the following properties:
`path`, `id`, and `isRoom`.

If the current path is `/dashboard` or `/`, then `isRoom` is false.
Else, the object also contains the following properties:
`name`, `description`, `welcomeMessage`, and `hostName`.

### API.COMMUNITY_CHANGE / API.ROOM_CHANGE
API event constant. This is called when the user changes communities.
It passes the information of the old and new communities to the callback.

```
API.on(API.COMMUNITY_CHANGE, callback);
function callback(oldCommunity, newCommunity) { ... }
```

### API.getPlaylists()
Returns an array of the user's playlists, each with the following properties:
`name`, `itemCount`, `active` and `$`.
