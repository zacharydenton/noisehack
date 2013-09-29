(function() {
  var createNoise, downloadSound, initAudio, renderWaveform;

  this.searchFreesound = function(params, callback) {
    var _this = this;
    return $.ajax({
      url: "http://www.freesound.org/api/sounds/search?api_key=ec0c281cc7404d14b6f5216f96b8cd7c",
      data: params,
      dataType: "jsonp",
      error: function(e) {
        return console.log(e);
      },
      success: function(data) {
        return callback(data.sounds);
      }
    });
  };

  this.getFreesoundSample = function(soundId, callback) {
    var _this = this;
    return $.ajax({
      url: "http://www.freesound.org/api/sounds/" + soundId + "?api_key=ec0c281cc7404d14b6f5216f96b8cd7c",
      dataType: "jsonp",
      error: function(e) {
        return console.log(e);
      },
      success: function(data) {
        return callback(data);
      }
    });
  };

  createNoise = function(context, duration) {
    var i, l, noise, r, _i, _ref;
    noise = context.createBuffer(2, duration * context.sampleRate, context.sampleRate);
    l = noise.getChannelData(0);
    r = noise.getChannelData(1);
    for (i = _i = 0, _ref = l.length; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
      l[i] = Math.random() * 2 - 1;
      r[i] = l[i];
    }
    return noise;
  };

  downloadSound = function(context, url, callback) {
    var request;
    request = new XMLHttpRequest();
    request.open("GET", url, true);
    request.responseType = "arraybuffer";
    request.onload = function() {
      return context.decodeAudioData(request.response, function(buffer) {
        return callback(buffer);
      });
    };
    return request.send();
  };

  initAudio = function(stream) {
    var context, convolver, filter, getFree, master, microphone, postAnalyser, preAnalyser;
    context = new webkitAudioContext();
    master = context.createGain();
    master.gain.value = 0.7;
    master.connect(context.destination);
    microphone = context.createMediaStreamSource(stream);
    convolver = context.createConvolver();
    convolver.buffer = createNoise(context, 1);
    filter = context.createBiquadFilter();
    filter.type = filter.ALLPASS;
    microphone.connect(filter);
    filter.connect(convolver);
    convolver.connect(master);
    getFree = function(id) {
      return getFreesoundSample(id, function(data) {
        return downloadSound(context, data['preview-hq-ogg'], function(buffer) {
          return convolver.buffer = buffer;
        });
      });
    };
    $("#sound").keypress(function(e) {
      if (e.keyCode === 13) {
        return getFree(e.target.value);
      }
    });
    getFree(163223);
    preAnalyser = context.createAnalyser();
    postAnalyser = context.createAnalyser();
    microphone.connect(preAnalyser);
    convolver.connect(postAnalyser);
    return renderWaveform(preAnalyser, postAnalyser);
  };

  renderWaveform = function(preAnalyser, postAnalyser) {
    var canvas, ctx, post, pre, render, x;
    canvas = $("#waveform")[0];
    ctx = canvas.getContext('2d');
    pre = new Uint8Array(preAnalyser.frequencyBinCount);
    post = new Uint8Array(postAnalyser.frequencyBinCount);
    x = 0;
    render = function() {
      var i, s, _i, _ref;
      requestAnimationFrame(render);
      preAnalyser.getByteFrequencyData(pre);
      postAnalyser.getByteFrequencyData(post);
      for (i = _i = 0, _ref = pre.length / 2; 0 <= _ref ? _i < _ref : _i > _ref; i = 0 <= _ref ? ++_i : --_i) {
        s = i;
        ctx.fillStyle = "rgba(" + pre[s] + ", 0, 0, 0.7)";
        ctx.fillRect(x, 2 * i, 1, 2);
        ctx.fillStyle = "rgba(0, 0, " + post[s] + ", 0.5)";
        ctx.fillRect(x, 2 * i, 1, 2);
      }
      x++;
      if (x > canvas.width) {
        return x = 0;
      }
    };
    return render();
  };

  $(function() {
    var t;
    navigator.webkitGetUserMedia({
      audio: true
    }, initAudio);
    $(window).resize(function() {
      $("#waveform")[0].width = window.innerWidth;
      return $("#waveform")[0].height = window.innerHeight;
    });
    t = null;
    return $(window).mousemove(function() {
      var hide;
      clearTimeout(t);
      $("#sound").css('visibility', 'visible');
      hide = function() {
        if (!$("*:focus").is("input")) {
          return $("#sound").css('visibility', 'hidden');
        }
      };
      return t = setTimeout(hide, 500);
    });
  });

}).call(this);
