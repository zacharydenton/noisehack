// Generated by CoffeeScript 1.6.2
(function() {
  $(function() {
    return $('h1, h2, h3, li, p').each(function() {
      return $(this).html($(this).html().replace(/\s([\w.:-\(\)]+)$/, '&nbsp;$1'));
    });
  });

}).call(this);
