---
title: Custom Audio Effects in JavaScript with the Web Audio API
excerpt: Learn how to implement custom effects and filters with the Web Audio API.
---

You can get pretty far with the built-in Web Audio API nodes, but to
really turn things up to 11, you may need to write custom audio effects
in JavaScript. This post shows you how.

<!--more-->

To demonstrate the effects, we'll be using the following reference tone
throughout the post:

<pre style="display: none">var effect = audioContext.createGainNode();</pre>
<p><button class="demo">
Reference Tone
</button></p>

Simple Lowpass Filter
---------------------

Let's get warmed up with a [simple lowpass filter][]. This filter simply
averages the current input sample with the previous output sample:

~~~~ {.javascript}
var bufferSize = 4096;
var effect = (function() {
    var lastOut = 0.0;
    var node = audioContext.createScriptProcessor(bufferSize, 1, 1);
    node.onaudioprocess = function(e) {
        var input = e.inputBuffer.getChannelData(0);
        var output = e.outputBuffer.getChannelData(0);
        for (var i = 0; i < bufferSize; i++) {
            output[i] = (input[i] + lastOut) / 2.0;
            lastOut = output[i];
        }
    }
    return node;
})();
~~~~

<p><button class="demo">
Simple Lowpass
</button></p>

I don't know about you, but I could barely tell a difference between
that and the reference tone. But take a look at how the effect is coded
-- this will serve as the basic template for all of the upcoming audio
effects.

The first thing to note is the buffer size. Set it too low, and you'll
get audio glitches known as [buffer underruns][]. Set it too high, and
you'll introduce latency. Set it to 0, and the Web Audio API will pick a
value for you.

Now for the actual filter definition. I've wrapped it all in a closure
to encapsulate the filter's internal state (in this case, the previous
output sample, `lastOut`). The `AudioNode` that actually performs the
computation is the `ScriptProcessor`. To create a `ScriptProcessor`, use
`audioContext.createScriptProcessor()`:

~~~~ {.javascript}
audioContext.createScriptProcessor(bufferSize, numInputChannels, numOutputChannels);
~~~~

Take a look at how `node` is instantiated: 1 for `numInputChannels` and
1 for `numOutputChannels`. This means that this simple lowpass filter
processes audio in mono. The good news is that we don't have to worry
about down-mixing from stereo and up-mixing back to stereo -- the Web
Audio API takes care of all that automatically.

The magic happens within the `onaudioprocess` callback. Within this
callback, we get access to two buffers: one for reading the incoming
audio data, and the other for writing the outgoing audio data. Each of
these is an array of size `bufferSize`. The general pattern for the
`onaudioprocess` callback is to loop through each sample of input,
modify it somehow, and write the corresponding sample of output.

At this point, you may be wondering how to actually use this effect. It
turns out that these custom effects use exactly the same interface as
any other `AudioNode`:

~~~~ {.javascript}
var oscillator = audioContext.createOscillator();
oscillator.connect(effect);
effect.connect(audioContext.destination);
~~~~

On the other hand, this effect doesn't really do much, and I can't think
of any reason why you'd use it instead of the existing `BiquadFilter`.
Let's take a look at some more interesting effects.

Pinking Filter
--------------

Previously, I demonstrated how to [generate pink noise with the Web
Audio API][]. It was implemented as a series of filters designed to
reduce the amplitude of white noise by 3dB per octave. We can use this
same filter series on *any* input signal -- not just white noise.

~~~~ {.javascript}
var bufferSize = 4096;
var effect = (function() {
    var b0, b1, b2, b3, b4, b5, b6;
    b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0;
    var node = audioContext.createScriptProcessor(bufferSize, 1, 1);
    node.onaudioprocess = function(e) {
        var input = e.inputBuffer.getChannelData(0);
        var output = e.outputBuffer.getChannelData(0);
        for (var i = 0; i < bufferSize; i++) {
            b0 = 0.99886 * b0 + input[i] * 0.0555179;
            b1 = 0.99332 * b1 + input[i] * 0.0750759;
            b2 = 0.96900 * b2 + input[i] * 0.1538520;
            b3 = 0.86650 * b3 + input[i] * 0.3104856;
            b4 = 0.55000 * b4 + input[i] * 0.5329522;
            b5 = -0.7616 * b5 - input[i] * 0.0168980;
            output[i] = b0 + b1 + b2 + b3 + b4 + b5 + b6 + input[i] * 0.5362;
            output[i] *= 0.11; // (roughly) compensate for gain
            b6 = input[i] * 0.115926;
        }
    }
    return node;
})();
~~~~

<p><button class="demo">
Pinking Filter
</button></p>

Qualitatively speaking, the filter smooths out the reference tone and
makes it less "harsh" -- kind of like the relationship between pink
noise and white noise.

If you look closely, this filter is using the same basic technique as
the simple lowpass filter (averaging the last output sample with the
current input sample). The only difference is that now there's six
simple lowpass filters, where previously there was only one. In other
words, filter `b0` averages its last output sample (the previous value
of `b0`) with the current input sample, `b1` averages its last output
sample (the previous value of `b1`) with the current input sample, and
so on. These six filters are then combined together with the appropriate
weights to approximate a -3dB/octave filter, in aggregate.

Noise Convolver
---------------

The `ConvolverNode` is arguably the most powerful node in the Web Audio
arsenal. Combined with JavaScript, it's absolutely devastating.

~~~~ {.javascript}
var effect = (function() {
    var convolver = audioContext.createConvolver(),
        noiseBuffer = audioContext.createBuffer(2, 0.5 * audioContext.sampleRate, audioContext.sampleRate),
        left = noiseBuffer.getChannelData(0),
        right = noiseBuffer.getChannelData(1);
    for (var i = 0; i < noiseBuffer.length; i++) {
        left[i] = Math.random() * 2 - 1;
        right[i] = Math.random() * 2 - 1;
    }
    convolver.buffer = noiseBuffer;
    return convolver;
})();
~~~~

<p><button class="demo">
Noise Convolver
</button></p>

So what we've done here is create 0.5 seconds of stereophonic white
noise and a `ConvolverNode` that uses it. You can create some really
interesting effects with this technique: create a sound buffer with
JavaScript, then use it to convolve an arbitrary input signal.

If you don't know much about convolution, that's OK. I'll be covering
the `ConvolverNode` in depth in a future post. For now, I'll just say
that you can use it to emulate anything from the reverb of a massive
cathedral hall to the tone of a [Vox AC30][].

Moog Filter
-----------

Many have tried to emulate the [classic Moog filter][]; few have
succeeded. The following is based on [a pretty good approximation][]:

~~~~ {.javascript}
var bufferSize = 4096;
var effect = (function() {
    var node = audioContext.createScriptProcessor(bufferSize, 1, 1);
    var in1, in2, in3, in4, out1, out2, out3, out4;
    in1 = in2 = in3 = in4 = out1 = out2 = out3 = out4 = 0.0;
    node.cutoff = 0.065; // between 0.0 and 1.0
    node.resonance = 3.99; // between 0.0 and 4.0
    node.onaudioprocess = function(e) {
        var input = e.inputBuffer.getChannelData(0);
        var output = e.outputBuffer.getChannelData(0);
        var f = node.cutoff * 1.16;
        var fb = node.resonance * (1.0 - 0.15 * f * f);
        for (var i = 0; i < bufferSize; i++) {
            input[i] -= out4 * fb;
            input[i] *= 0.35013 * (f*f)*(f*f);
            out1 = input[i] + 0.3 * in1 + (1 - f) * out1; // Pole 1
            in1 = input[i];
            out2 = out1 + 0.3 * in2 + (1 - f) * out2; // Pole 2
            in2 = out1;
            out3 = out2 + 0.3 * in3 + (1 - f) * out3; // Pole 3
            in3 = out2;
            out4 = out3 + 0.3 * in4 + (1 - f) * out4; // Pole 4
            in4 = out3;
            output[i] = out4;
        }
    }
    return node;
})();
~~~~

<p><button class="demo">
Moog Filter
</button></p>

Notice the resonance. The caveat with this approach is that you can't
modulate `cutoff` and `frequency` the way you can with a normal
`AudioParam`. I thought I could get around this by creating a dummy
`BiquadFilter` and hijacking its `frequency` and `Q` parameters.
Unfortunately, the [`computedValue` attribute referenced in the docs][]
doesn't appear to be publicly accessible. If anyone knows a way around
this, I'd be very interested to hear about it.

Bitcrusher
----------

Let's take a look at one last effect: the lo-fi bitcrusher ([based on this code][]):

~~~~ {.javascript}
var bufferSize = 4096;
var effect = (function() {
    var node = audioContext.createScriptProcessor(bufferSize, 1, 1);
    node.bits = 4; // between 1 and 16
    node.normfreq = 0.1; // between 0.0 and 1.0
    var step = Math.pow(1/2, node.bits);
    var phaser = 0;
    var last = 0;
    node.onaudioprocess = function(e) {
        var input = e.inputBuffer.getChannelData(0);
        var output = e.outputBuffer.getChannelData(0);
        for (var i = 0; i < bufferSize; i++) {
            phaser += node.normfreq;
            if (phaser >= 1.0) {
                phaser -= 1.0;
                last = step * Math.floor(input[i] / step + 0.5);
            }
            output[i] = last;
        }
    };
    return node;
})();
~~~~

<p><button class="demo">
Bitcrusher
</button></p>

It works by quantizing the input signal. In other words, it samples the
input signal every so often, then "holds" that sample until it's time to
sample again (based on the `bits` and `normfreq` settings).

Conclusion
----------

Hopefully this will get you started implementing some crazy audio
effects. There's a whole [wild world of DSP algorithms][] out there,
just waiting to be implemented in JavaScript.

For a great practical
introduction to the art of programming audio effects, I highly recommend
[Designing Audio Effect Plug-Ins in C++][]. It was published in 2013 and
covers the [cutting-edge of virtual analog filter design][], among many
other interesting topics.

As I was researching for this article, I noticed there's not really any
good central repository for DSP effects. With the Web Audio API, a [GLSL
sandbox][] for audio effects is suddenly possible. I think a central
repository for open-source audio effects with in-browser previews would
be really cool. If anyone is interested in building such a platform,
[let me know][].

<script>
$(function() {
    var audioContext = new (typeof AudioContext !== "undefined" && AudioContext !== null ? AudioContext : webkitAudioContext);
    var masterGain = audioContext.createGain();
    masterGain.gain.value = 0.1;
    masterGain.connect(audioContext.destination);

    var stopDemo = function($button) {
        $button.removeAttr('disabled');
    };

    var startDemo = function($button) {
        var now = audioContext.currentTime;

        var effect = eval($button.parent().prev('pre').text() + "effect;");
        var sawWave = audioContext.createOscillator();
        sawWave.type = sawWave.SAWTOOTH;
        sawWave.start(now);
        var effectGain = audioContext.createGain();

        effect.connect(effectGain);
        effectGain.connect(masterGain);
        sawWave.connect(effect);

        /* Sweep from A3 to A6. */
        sawWave.frequency.setValueAtTime(220, now);
        sawWave.frequency.linearRampToValueAtTime(1760, now + 4);

        /* Play raw wave through effect, then fade out. */
        effectGain.gain.setValueAtTime(1.0, now);
        effectGain.gain.setValueAtTime(1.0, now + 4);
        effectGain.gain.linearRampToValueAtTime(0.0, now + 5);

        $button.attr('disabled', '');
        setTimeout(function() { stopDemo($button); }, 5000);
    };

    $("button.demo").each(function(i, button) {
        $(button).click(function(e) {
            var $button = $(this);
            if ($button.attr('disabled')) {
                stopDemo($button);
            } else {
                startDemo($button);
            }
        });
    });
});
</script>





  [simple lowpass filter]: http://en.wikipedia.org/wiki/Low-pass_filter#Simple_infinite_impulse_response_filter
  [buffer underruns]: http://en.wikipedia.org/wiki/Buffer_underrun
  [generate pink noise with the Web Audio API]: /generate-noise-web-audio-api/#pink-noise
  [Vox AC30]: http://www.amazon.com/dp/B002PYRHFU/?tag=zacden-20
  [classic Moog filter]: http://en.wikipedia.org/wiki/Minimoog
  [a pretty good approximation]: http://www.musicdsp.org/showArchiveComment.php?ArchiveID=26
  [`computedValue` attribute referenced in the docs]: https://dvcs.w3.org/hg/audio/raw-file/tip/webaudio/specification.html#computedValue-AudioParam-section
  [based on this code]: http://www.musicdsp.org/showArchiveComment.php?ArchiveID=139
  [wild world of DSP algorithms]: http://musicdsp.org/
  [Designing Audio Effect Plug-Ins in C++]: http://www.amazon.com/dp/0240825152/?tag=zacden-20
  [cutting-edge of virtual analog filter design]: /research/VAFilterDesign_1.0.3.pdf
  [GLSL sandbox]: http://glsl.heroku.com/
  [let me know]: mailto:zach@noisehack.com
