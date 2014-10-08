// Generated by CoffeeScript 1.8.0
(function() {
  var setShadow;

  setShadow = function() {
    var $header, length, letter, newText, offset, phi, text, width, _i, _len;
    $header = $('header h1 a');
    text = $header.text();
    length = text.length;
    newText = '';
    phi = 1.61803399;
    if ($(window).width() >= 900) {
      width = -Math.pow(phi, -2);
    } else {
      width = -Math.pow(phi, -3);
    }
    offset = -width;
    for (_i = 0, _len = text.length; _i < _len; _i++) {
      letter = text[_i];
      if (letter === 'e') {
        offset = 0;
      }
      newText += "<span style='text-shadow: " + offset + "rem " + (Math.abs(width)) + "rem rgba(254, 254, 34, 0.5)'>" + letter + "</span>";
      offset += 2 * width / (length - 1);
    }
    $header.css('text-shadow', 'none');
    return $header.html(newText);
  };

  $(function() {
    $(window).resize(setShadow);
    return setShadow();
  });

}).call(this);