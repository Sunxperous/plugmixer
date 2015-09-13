# ![](https://raw.githubusercontent.com/Sunxperous/plugmixer/master/images/icon48.png) [Plugmixer](https://plugmixer.sunwj.com)

## Playlist management for plug.dj!

### To start using Plugmixer, visit [plugmixer.sunwj.com](https://plugmixer.sunwj.com)

## Setup and development

Plugmixer uses the following npm modules:

1. [coffee-script](https://github.com/jashkenas/coffeescript) for compilation of CoffeeScript,
1. [uglify-js](https://github.com/mishoo/UglifyJS2) to compress and minify JavaScript, and
1. [http-server](https://github.com/nodeapps/http-server) for serving local files.

The CoffeeScript files to be compiled and JavaScript files to be compressed are defined in `build.sh`. Running `build.sh` generates the minified files in the `/release` directory. Refer to `release/defines.sample.js` for the additional configuration files required.

Use `http-server -S --cors` to serve files over HTTPS and enable CORS via the `Access-Control-Allow-Origin` header.

## Extended API

[`core/extendAPI.js`](core/extendAPI.js) extends the current plug.dj API. Refer to [API.md](API.md) for more information.
