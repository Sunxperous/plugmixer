# ![](https://raw.githubusercontent.com/Sunxperous/plugmixer/master/icon48.png) Plugmixer

#### Overcome the 200 item count limit in plug.dj playlists with this script!

This plug.dj script/extension allows you to play music from two or more of your playlists without having to activate them manually. Each time you DJ, one playlist will be activated randomly for your next turn.

[![](https://developer.chrome.com/webstore/images/ChromeWebStore_Badge_v2_206x58.png)](https://chrome.google.com/webstore/detail/plugmixer/bnfboihohdckgijdkplinpflifbbfmhm)

## Bookmark script

### Activating the script

Copy and save the following as a bookmark:

    javascript:(function(){$.getScript('https://dl.dropboxusercontent.com/u/10543516/plugmixer.js');}());
    
Click the bookmark when you are in plug.dj, and an indicator should show near the bottom right corner of the screen.

### Disabling playlists

Click on a playlist's __item count__ in the playlist menu to disable it. Disabled playlists are faded, and will not be activated by Plugmixer.

Clicking on the __item count__ again enables the playlist.

Note that playlist states are _not persistent_ across __bookmarked script__ loads. All playlists will be re-enabled on each script load, and as such, also on each plug.dj refresh.

Playlist states are _persistent_ on the Chrome extension.

### Deactivating Plugmixer

Click on the __Active__ button on the Plugmixer indicator to deactivate Plugmixer.

[1]: http://google.com
