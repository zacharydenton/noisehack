$ ->
  $('h1, h2, h3, li, p').each ->
    $(this).html($(this).html().replace(/\s([\w.:\(\)\-]+)$/, '&nbsp;$1'))
