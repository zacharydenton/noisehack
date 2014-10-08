@searchFreesound = (params, callback) ->
  $.ajax
    url: "//www.freesound.org/api/sounds/search?api_key=ec0c281cc7404d14b6f5216f96b8cd7c"
    data: params
    dataType: "jsonp"
    error: (e) ->
      console.log(e)
    success: (data) =>
      callback data.sounds

@getFreesoundSample = (soundId, callback) ->
  $.ajax
    url: "//www.freesound.org/api/sounds/#{soundId}?api_key=ec0c281cc7404d14b6f5216f96b8cd7c"
    dataType: "jsonp"
    error: (e) ->
      console.log(e)
    success: (data) =>
      callback data

createNoise = (context, duration) ->
  noise = context.createBuffer(2, duration * context.sampleRate, context.sampleRate)
  l = noise.getChannelData(0)
  r = noise.getChannelData(1)
  for i in [0...l.length]
    l[i] = Math.random() * 2 - 1
    r[i] = l[i]
  noise

downloadSound = (context, url, callback) ->
  request = new XMLHttpRequest()
  request.open "GET", url, true
  request.responseType = "arraybuffer"
  request.onload = ->
    context.decodeAudioData request.response, (buffer) ->
      callback buffer
  request.send()

initAudio = (stream) ->
  context = new webkitAudioContext()
  master = context.createGain()
  master.gain.value = 0.7
  master.connect context.destination
  microphone = context.createMediaStreamSource(stream)
  convolver = context.createConvolver()
  convolver.buffer = createNoise(context, 1)
  filter = context.createBiquadFilter()
  filter.type = filter.ALLPASS
  microphone.connect filter
  filter.connect convolver
  convolver.connect master

  getFree = (id) ->
    getFreesoundSample id, (data) ->
      downloadSound context, data['preview-hq-ogg'], (buffer) ->
        convolver.buffer = buffer
  $("#sound").keypress (e) ->
    if e.keyCode == 13
      getFree e.target.value
  getFree 163223
  preAnalyser = context.createAnalyser()
  postAnalyser = context.createAnalyser()
  microphone.connect preAnalyser
  convolver.connect postAnalyser
  renderWaveform preAnalyser, postAnalyser

renderWaveform = (preAnalyser, postAnalyser) ->
  canvas = $("#waveform")[0]
  ctx = canvas.getContext '2d'
  pre = new Uint8Array(preAnalyser.frequencyBinCount)
  post = new Uint8Array(postAnalyser.frequencyBinCount)
  x = 0
  render = ->
    requestAnimationFrame render
    preAnalyser.getByteFrequencyData pre
    postAnalyser.getByteFrequencyData post
    for i in [0...pre.length/2]
      #s = Math.floor((i * pre.length + canvas.height / 2) / canvas.height)
      s = i
      ctx.fillStyle = "rgba(#{pre[s]}, 0, 0, 0.7)"
      ctx.fillRect x, 2*i, 1, 2
      ctx.fillStyle = "rgba(0, 0, #{post[s]}, 0.5)"
      ctx.fillRect x, 2*i, 1, 2
    x++
    if x > canvas.width
      x = 0
  render()

$ ->
  navigator.webkitGetUserMedia audio: true, initAudio
  $(window).resize ->
    $("#waveform")[0].width = window.innerWidth
    $("#waveform")[0].height = window.innerHeight

  t = null
  $(window).mousemove ->
    clearTimeout t
    $("#sound").css 'visibility', 'visible'
    hide = ->
      $("#sound").css 'visibility', 'hidden' unless $("*:focus").is("input")
    t = setTimeout hide, 500
