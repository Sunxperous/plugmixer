// Generated by CoffeeScript 1.7.1
'use strict';
var OPACITY, SHIFT_LEFT, clickSelection, inputting, sameEnabledPlaylists, tabId;

OPACITY = '0.3';

SHIFT_LEFT = '-63px';

tabId = null;

sameEnabledPlaylists = function(storageData, activeData) {
  storageData.splice(0, 1);
  return $(storageData).not(activeData).length === 0 && $(activeData).not(storageData).length === 0;
};

chrome.tabs.query({
  active: true,
  currentWindow: true
}, function(tabs) {
  tabId = tabs[0].id;
  chrome.pageAction.getTitle({
    tabId: tabId
  }, function(result) {
    if (result === 'Plugmixer') {
      $('.toggle').css('left', SHIFT_LEFT);
      return $('.inactive').css('opacity', OPACITY);
    } else {
      return $('.active').css('opacity', OPACITY);
    }
  });
  return chrome.tabs.sendMessage(tabId, 'plugmixer_get_selections', function(info) {
    return chrome.storage.sync.get(info.selections, function(data) {
      var clone, selectionId, _i, _len, _ref, _results;
      _ref = info.selections;
      _results = [];
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        selectionId = _ref[_i];
        clone = $('.template').clone();
        clone.children('.name').text(data[selectionId][0]);
        if (sameEnabledPlaylists(data[selectionId], info.activePlaylists)) {
          clone.addClass('inUse');
        }
        clone.removeClass('template');
        $('#list').append(clone);
        clone.animate({
          'height': 'toggle'
        });
        _results.push(clone.click(selectionId, clickSelection));
      }
      return _results;
    });
  });
});

$('#status').click(function(event) {
  return chrome.tabs.sendMessage(tabId, 'plugmixer_toggle_status', function(response) {
    if (response === 'plugmixer_make_active') {
      $('.inactive').animate({
        'opacity': OPACITY,
        'left': SHIFT_LEFT
      });
      return $('.active').animate({
        'opacity': '1',
        'left': SHIFT_LEFT
      });
    } else {
      $('.inactive').animate({
        'opacity': '1',
        'left': '0'
      });
      return $('.active').animate({
        'opacity': OPACITY,
        'left': '0'
      });
    }
  });
});

clickSelection = function(event) {
  if (event.target.className === 'delete') {
    return chrome.tabs.sendMessage(tabId, {
      about: 'plugmixer_delete_selection',
      selectionId: event.data
    }, (function(_this) {
      return function(response) {
        if (response === 'plugmixer_selection_deleted') {
          return $(_this).animate({
            'height': 'hide'
          }, 256, function(animation, jumpedtoEnd) {
            return $(this).remove();
          });
        }
      };
    })(this));
  } else {
    chrome.tabs.sendMessage(tabId, {
      about: 'plugmixer_choose_selection',
      selectionId: event.data
    });
    $('.selection').removeClass('inUse');
    return $(this).addClass('inUse');
  }
};

$('#save').hover((function(event) {
  return $('#selections .title').text('Save current selection');
}), (function(event) {
  if (inputting !== 1) {
    return $('#selections .title').text('PLAYLIST GROUPS');
  }
}));

inputting = 0;

$('#save').click(function(event) {
  if (inputting === 1) {
    $('#save').html('+');
    inputting = 2;
    return $('.input').animate({
      'height': 'toggle',
      'opacity': '0'
    }, 256, function(animation, jumpedToEnd) {
      $('#new').val('');
      return inputting = 0;
    });
  } else if (inputting === 0) {
    $('#save').html('&times;');
    $('#selections .title').text('Save current selection');
    inputting = 1;
    return $('.input').animate({
      'height': 'toggle',
      'opacity': '1'
    }, 256, function(animation, jumpedToEnd) {
      return $('#new').focus();
    });
  }
});

$('#new').keyup(function(event) {
  var name;
  if (inputting === 1 && event.keyCode === 13) {
    name = $('#new').val();
    if (name.length > 0) {
      return chrome.tabs.sendMessage(tabId, {
        about: 'plugmixer_save_selection',
        name: name
      }, function(response) {
        if (response.about === 'plugmixer_selection_saved') {
          $('#save').html('+');
          inputting = 2;
          return $('.input').animate({
            'height': 'toggle'
          }, 256, function(animation, jumpedToEnd) {
            var clone;
            $('#new').val('');
            inputting = 0;
            clone = $('.template').clone();
            clone.children('.name').text(name);
            $('.template').after(clone);
            clone.removeClass('template').addClass('inUse');
            clone.animate({
              'height': 'toggle'
            });
            return clone.click(response.selectionId, clickSelection);
          });
        }
      });
    }
  }
});
