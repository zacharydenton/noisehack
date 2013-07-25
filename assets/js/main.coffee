setShadow = ->
  $header = $('header h1 a')
  text = $header.text()
  length = text.length
  newText = ''
  phi = 1.61803399
  if $(window).width() >= 900
    width = -Math.pow(phi, -2)
  else
    width = -Math.pow(phi, -3)
  offset = -width
  for letter in text
    if letter is 'e' then offset = 0
    newText += "<span style='text-shadow: #{offset}rem #{Math.abs width}rem rgba(254, 254, 34, 0.5)'>#{letter}</span>"
    offset += 2 * width / (length - 1)
  $header.css 'text-shadow', 'none'
  $header.html newText

$ ->
  $('h1, h2, h3, li, p, li a').each ->
    $(this).html($(this).html().replace(/\s([\w.:\(\)\-]+)$/, '&nbsp;$1'))
  $(window).resize setShadow
  setShadow()
