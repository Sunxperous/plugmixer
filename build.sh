#!/bin/sh

uglifyjs ./core/extendAPI.js -c -m -o ./release/extendAPI.js

cp ./core/plugmixer.html ./release/plugmixer.html

coffee -c ./core/plugmixer.coffee
uglifyjs ./release/plugmixer.define.js ./core/plugmixer.js -c -m -o ./release/plugmixer.js

coffee -c ./local/plugmixer_local.coffee
uglifyjs ./release/plugmixer_local.define.js ./local/plugmixer_local.js -c -m -o ./release/plugmixer_local.js

coffee -c ./chrome/contentscript.coffee
uglifyjs ./release/plugmixer_local.define.js ./chrome/contentscript.js -c -m -o ./chrome/contentscript.js
