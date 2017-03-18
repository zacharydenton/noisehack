---
title: How to Generate Noise with the Web Audio API
excerpt: Learn how to generate white noise, pink noise, and brown noise with the Web Audio API.
---

One of the main shortcomings of the [Web Audio API][] is that there's no
native support for generating noise. This post will teach you how to
overcome that limitation.

<!--more-->

If you want to skip to the good part, check out [the demo][]. Also, I've
packaged all the noise generators into a small library called [noise.js
(available on GitHub)][].

White Noise
-----------

The most common type of noise is *white noise*. White noise is perfectly
random audio data with a flat frequency spectrum.

To produce white noise, we simply compute a series of random
samples[^1]. One way to do this with the Web Audio API is to use a
`ScriptProcessorNode`:

~~~~ {.javascript}
var bufferSize = 4096;
var whiteNoise = audioContext.createScriptProcessor(bufferSize, 1, 1);
whiteNoise.onaudioprocess = function(e) {
    var output = e.outputBuffer.getChannelData(0);
    for (var i = 0; i < bufferSize; i++) {
        output[i] = Math.random() * 2 - 1;
    }
}

whiteNoise.connect(audioContext.destination);
~~~~

This works, but depending on the application, [it might be
inefficient][]. With a buffer size of 4096, the `onaudioprocess`
callback is being executed around 10 times per second. Not a problem if
you're building an ambient sound generator that only uses a single
instance of white noise, but if you're building, say, a polyphonic
synthesizer with noise-modulated filters, this computational overhead
will introduce latency.

A more efficient approach is to generate a buffer of white noise and
then loop through it:

~~~~ {.javascript}
var bufferSize = 2 * audioContext.sampleRate,
    noiseBuffer = audioContext.createBuffer(1, bufferSize, audioContext.sampleRate),
    output = noiseBuffer.getChannelData(0);
for (var i = 0; i < bufferSize; i++) {
    output[i] = Math.random() * 2 - 1;
}

var whiteNoise = audioContext.createBufferSource();
whiteNoise.buffer = noiseBuffer;
whiteNoise.loop = true;
whiteNoise.start(0);

whiteNoise.connect(audioContext.destination);
~~~~

This code generates two seconds of white noise and then loops through it
continuously. The primary disadvantage of this approach is that the same
chunk of noise is being reused, over and over. Depending on how large
the noise buffer is, this means you might be able to hear the noise
repeating. In practice, I've found that this is only noticeable when the
noise buffer is less than two seconds long.

Pink Noise
----------

The next type of noise we'll be generating is *pink noise*. Whereas
white noise has equal power across the frequency spectrum, pink noise
*sounds* like it has equal power across the frequency spectrum. Our ears
process frequencies logarithmically, and pink noise takes this into
account. In terms of ambient noise, I find that pink noise sounds *much*
nicer than white noise, which is too harsh in the upper frequencies.

To generate pink noise, we'll approximate the effects of a -3dB/octave
filter using [Paul Kellet's refined method][]:

~~~~ {.javascript}
var bufferSize = 4096;
var pinkNoise = (function() {
    var b0, b1, b2, b3, b4, b5, b6;
    b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0;
    var node = audioContext.createScriptProcessor(bufferSize, 1, 1);
    node.onaudioprocess = function(e) {
        var output = e.outputBuffer.getChannelData(0);
        for (var i = 0; i < bufferSize; i++) {
            var white = Math.random() * 2 - 1;
            b0 = 0.99886 * b0 + white * 0.0555179;
            b1 = 0.99332 * b1 + white * 0.0750759;
            b2 = 0.96900 * b2 + white * 0.1538520;
            b3 = 0.86650 * b3 + white * 0.3104856;
            b4 = 0.55000 * b4 + white * 0.5329522;
            b5 = -0.7616 * b5 - white * 0.0168980;
            output[i] = b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362;
            output[i] *= 0.11; // (roughly) compensate for gain
            b6 = white * 0.115926;
        }
    }
    return node;
})();

pinkNoise.connect(audioContext.destination);
~~~~

So the code to generate pink noise is quite a bit more complex than the
code to generate white noise. The `pinkNoise` node is wrapped within a
closure because we want the values of `b0` through `b6` (the filter
state) to persist between calls to `onaudioprocess`. The 0.11 scaling
factor is taken from the [Csound source code][].

Brownian Noise
--------------

Let's move on to *Brownian noise* (also known as brown noise or red
noise). Brownian noise decreases in power by 12dB/octave, and sounds
like a waterfall. Here's how to generate Brownian noise with the Web
Audio API:

~~~~ {.javascript}
var bufferSize = 4096;
var brownNoise = (function() {
    var lastOut = 0.0;
    var node = audioContext.createScriptProcessor(bufferSize, 1, 1);
    node.onaudioprocess = function(e) {
        var output = e.outputBuffer.getChannelData(0);
        for (var i = 0; i < bufferSize; i++) {
            var white = Math.random() * 2 - 1;
            output[i] = (lastOut + (0.02 * white)) / 1.02;
            lastOut = output[i];
            output[i] *= 3.5; // (roughly) compensate for gain
        }
    }
    return node;
})();

brownNoise.connect(audioContext.destination);
~~~~

Again, a closure is used to keep track of variables that need to persist
between calls to `onaudioprocess`.

Demo
----

Here are the three different kinds of noise in action:

<p>
<button id="white-demo">
White Noise
</button>
<button id="pink-demo">
Pink Noise
</button>
<button id="brown-demo">
Brown Noise
</button>
<script type="text/javascript" src="/js/noise.js"></script>
<script type="text/javascript">
var audioContext = new (window.webkitAudioContext || window.AudioContext)();

var whiteNoise = audioContext.createWhiteNoise();
var whiteGain = audioContext.createGain();
whiteGain.gain.value = 0;
whiteNoise.connect(whiteGain);
whiteGain.connect(audioContext.destination);

var pinkNoise = audioContext.createPinkNoise();
var pinkGain = audioContext.createGain();
pinkGain.gain.value = 0;
pinkNoise.connect(pinkGain);
pinkGain.connect(audioContext.destination);

var brownNoise = audioContext.createBrownNoise();
var brownGain = audioContext.createGain();
brownGain.gain.value = 0;
brownNoise.connect(brownGain);
brownGain.connect(audioContext.destination);

var toggleDemo = function(text, gain) {
    var handler = function(e) {
        if (gain.gain.value == 0.0) {
            $(e.target).text("Stop");
            gain.gain.value = 0.3;
        } else {
            $(e.target).text(text);
            gain.gain.value = 0.0;
        }
    };
    return handler;
};

$("#white-demo").click(toggleDemo("White Noise", whiteGain));
$("#pink-demo").click(toggleDemo("Pink Noise", pinkGain));
$("#brown-demo").click(toggleDemo("Brown Noise", brownGain));
</script>
</p>

Just click on the buttons to turn the noise on and off.

[^1]: In the Web Audio API, samples are floating-point numbers in the
    range [-1.0, 1.0].

  [Web Audio API]: https://dvcs.w3.org/hg/audio/raw-file/tip/webaudio/specification.html
  [the demo]: #demo
  [noise.js (available on GitHub)]: https://github.com/zacharydenton/noise.js
  [it might be inefficient]: https://medium.com/web-audio/61a836e28b42
  [Paul Kellet's refined method]: http://www.musicdsp.org/files/pink.txt
  [Csound source code]: http://sourceforge.net/p/csound/csound6-git/ci/master/tree/Opcodes/pitch.c#l1336
