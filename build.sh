#!/bin/sh

uglifyjs ./core/extendAPI.js -b -o ./release/current/extendAPI.js

cp ./core/plugmixer.html ./release/current/plugmixer.html

coffee -c ./core/plugmixer.coffee
uglifyjs ./release/plugmixer.define.js ./core/plugmixer.js -b -o ./release/current/plugmixer.js

coffee -c ./local/plugmixer_local.coffee
uglifyjs ./release/plugmixer_local.define.js ./local/plugmixer_local.js -b -o ./release/current/plugmixer_local.js

coffee -c ./chrome/contentscript.coffee
uglifyjs ./release/plugmixer_local.define.js ./chrome/contentscript.js -b -o ./chrome/contentscript.js

coffee -c ./chrome/background.coffee
uglifyjs ./chrome/background.js -b -o ./chrome/background.js

zip -r ./release/current/chrome.zip ./chrome/background.js ./chrome/contentscript.js ./chrome/popup.html ./images ./manifest.json
