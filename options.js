// Generated by CoffeeScript 1.6.3
(function() {
  document.addEventListener('DOMContentLoaded', function() {
    return chrome.storage.sync.get({
      indicator: 'both'
    }, function(data) {
      var radio, radios, _i, _len, _results;
      radios = document.getElementsByName('indicator');
      _results = [];
      for (_i = 0, _len = radios.length; _i < _len; _i++) {
        radio = radios[_i];
        if (radio.value === data.indicator) {
          _results.push(radio.checked = true);
        } else {
          _results.push(void 0);
        }
      }
      return _results;
    });
  });

  document.getElementById('save').addEventListener('click', function() {
    var indicator, radio, radios, _i, _len, _results;
    radios = document.getElementsByName('indicator');
    _results = [];
    for (_i = 0, _len = radios.length; _i < _len; _i++) {
      radio = radios[_i];
      if (radio.checked === true) {
        indicator = radio.value;
        _results.push(chrome.storage.sync.set({
          indicator: indicator
        }));
      } else {
        _results.push(void 0);
      }
    }
    return _results;
  });

}).call(this);