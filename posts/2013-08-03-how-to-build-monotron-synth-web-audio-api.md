---
title: How to Build a Monotron Synth with the Web Audio API
excerpt: Recreate the Korg Monotron synthesizer with JavaScript and the Web Audio API.
---

![Korg Monotron synthesizer][]

The [Monotron][] is an awesome little analog synth by Korg. In this
post, you'll learn how to recreate the Monotron with the Web Audio API.

This is a long post, so to get an idea of what you're building, check
out [the demo][] and [the code on GitHub][].

<!--more-->

Overview
--------

![Monotron block diagram][]

The Monotron is [a fairly simple synthesizer][], consisting of a
sawtooth oscillator (VCO), an LFO, and a lowpass filter (VCF). It's
monophonic, which means that only one note can be played at a time.

To recreate this synth, we'll break things up into three components.
First we've got the *audio circuit*, which generates sound with the Web
Audio API. Next, we've got the *control panel*, which corresponds to the
different knobs and switches on the Monotron. Finally, we've got the
*ribbon keyboard*, which triggers notes in response to user input.

The Monotron's ribbon keyboard is interesting: the transitions between
notes are seamless, so by sweeping your finger across the keyboard you
get a continuous change in pitch, like a [theremin][]. Quickly moving
your finger back and forth produces a cool vibrato effect.

The Audio Circuit
-----------------

Let's get started by implementing the core audio circuit. We'll use an
`OscillatorNode` for the VCO and LFO and a `BiquadFilterNode` for the
VCF. We'll encapsulate all of this functionality in a single `Monotron`
class:

~~~~ {.coffee}
class Monotron
  constructor: (@context) ->
    @vco = @context.createOscillator()
    @lfo = @context.createOscillator()
    @lfoGain = @context.createGain()
    @vcf = @context.createBiquadFilter()
    @output = @context.createGain()

    @vco.connect @vcf
    @vcf.connect @output
    @lfo.connect @lfoGain
    @lfoGain.connect @vcf.frequency

    @output.gain.value = 0
    @vco.type = @vco.SAWTOOTH
    @lfo.type = @lfo.SAWTOOTH
    @vco.start @context.currentTime
    @lfo.start @context.currentTime

  noteOn: (frequency, time) ->
    time ?= @context.currentTime
    @vco.frequency.setValueAtTime frequency, time
    @output.gain.linearRampToValueAtTime 1.0, time + 0.1

  noteOff: (time) ->
    time ?= @context.currentTime
    @output.gain.linearRampToValueAtTime 0.0, time + 0.1

  connect: (target) ->
    @output.connect target
~~~~

So the first thing the `Monotron` constructor does is create the
required audio nodes. As mentioned previously, we have the VCO, LFO, and
VCF -- but we also have two GainNodes: `@lfoGain` and `@output`.
`@lfoGain` controls how much of an effect the LFO has on the overall
sound -- it corresponds to the Monotron's LFO intensity knob. `@output`
is just a pattern I use when making Web Audio API instruments: it's
always the final node in the instrument's audio circuit, which gives
these instruments a consistent interface.

The second thing the constructor does is connect the audio nodes
together to form the audio circuit. This corresponds to the Monotron
block diagram above. The VCO is connected to the VCF, which is then
connected to the `@output` node. Then the LFO is connected to the LFO
amplifier (`@lfoGain`), which (by default) is connected to the VCF's
cutoff frequency. In addition to modulating the VCF, The Monotron also
supports modulating the VCO, which we'll implement later.

Finally, the constructor sets up some default parameters. The first
thing we want to do is silence the `@output` node. If we didn't, the
Monotron would start making noise as soon as it's connected. Second, we
specify that the VCO and LFO should produce sawtooth waves, just like on
the real Monotron. Finally, we start the VCO and LFO. This is something
that confused me when I first started programming synths: oscillators
actually remain "on" even when no note is being played. Thus we need a
way to shape the sound into separate notes.

In the `noteOn` method, the first thing is to schedule a change in VCO
pitch[^1]. Notice that `time` is an optional parameter: if not
specified, the pitch changes immediately. This way, the Monotron can
also be used with a sequencer which schedules notes ahead of time. Next,
we ramp the `@output` to full volume over a 0.1 second interval. (This
helps minimize "clicks" when notes are played.) The `noteOff` method
does the same, in reverse.

Lastly, we have the `connect` method. Like `@output`, this is a pattern
I use with all Web Audio synths, and is used in the same way as the
`connect` method of any `AudioNode`. For instance, to hook the Monotron
up to your speakers, you would use:

~~~~ {.javascript}
var audioContext = new webkitAudioContext();
var monotron = new Monotron(audioContext);
monotron.connect(audioContext.destination);
~~~~

Then you can play notes in the console like this:

~~~~ {.javascript}
monotron.noteOn(440);
monotron.noteOn(261.6);
monotron.noteOff();
~~~~

Which is cool, but it's not an instrument yet.

The Control Panel
-----------------

At this point, we have code that generates sound, but to make this a
real synthesizer we need a user interface. The Monotron has five knobs
to tweak the audio circuit and a switch to specify what the LFO
modulates. It also has a unique black and white visual style. It's
definitely worth the effort to make your synths look good.

So let's get started. We'll define the skeleton like this:

~~~~ {.html}
<div id="monotron">
  <div id="brand">
    <h1 id="title">Monotron</h1>
    <div id="description">Analogue Ribbon Synthesizer</div>
  </div>
  <div id="controls">
    <div class="panel">
      <label>
      <select id="mod">
        <option>Standby</option>
        <option>Pitch</option>
        <option>Cutoff</option>
      </select>
      <br />Mod
      </label>
    </div>
    <div class="panel">
      <h2>VCO</h2>
      <div class="knobs">
        <div class="knob">
          <input id="pitch" type="range" min="0" max="100" data-width="40" data-height="40" data-angleOffset="220" data-angleRange="280">
          <label>Pitch</label>
        </div>
      </div>
    </div>
    <div class="panel">
      <h2>LFO</h2>
      <div class="knobs">
        <div class="knob">
          <input id="rate" type="range" min="0" max="100" data-width="40" data-height="40" data-angleOffset="220" data-angleRange="280">
          <label>Rate</label>
        </div>
        <div class="knob">
          <input id="int" type="range" min="0" max="100" data-width="40" data-height="40" data-angleOffset="220" data-angleRange="280">
          <label>Int.</label>
        </div>
      </div>
    </div>
    <div class="panel">
      <h2>VCF</h2>
      <div class="knobs">
        <div class="knob">
          <input id="cutoff" type="range" min="0" max="100" data-width="40" data-height="40" data-angleOffset="220" data-angleRange="280">
          <label>Cutoff</label>
        </div>
        <div class="knob">
          <input id="peak" type="range" min="0" max="100" data-width="40" data-height="40" data-angleOffset="220" data-angleRange="280">
          <label>Peak</label>
        </div>
      </div>
    </div>
  </div>
  <div id="keyboard"></div>
</div>
~~~~

The `#brand`, `#controls`, and `#keyboard` divs correspond to the three
main sections of the Monotron interface. Within the `#controls` div, we
have four `.panel` divs: one for each of the horizontal control panels.

The first thing to do is style the `#monotron` container. As you can
see, it's mostly black, with white text and rounded white borders on the
sides. That roughly translates to CSS like this:

~~~~ {.css}
#monotron {
  background-color: #212121;
  border-left: 1rem solid #eaeeef;
  border-right: 1rem solid #eaeeef;
  border-radius: 0.38196601065988556rem;
  padding: 1.61803399rem;
  font-family: "Source Sans Pro", Arial, sans-serif;
  color: #eaeeef;
  width: 40rem;
}
~~~~

So we don't use exactly `#000` and `#fff` for the colors. I used
[Pixeur][] on the Monotron photo above to pick the right colors. The
other thing you'll notice about this CSS is the units. Lately I've been
using rems (root ems) instead of px when designing. rems are
resolution-independent units which means this design will scale
perfectly on any screen, regardless of DPI. You'll also notice that I've
specified the measurements as powers of *phi* (the golden ratio)[^2].
I'm not sure if this actually makes things look better, but it's a lot
easier than having to worry about individual pixels when laying things
out.

Next, let's style the `#brand` div. I'm using the [Audiowide][] font for
the Monotron logo.

~~~~ {.css}
h1, h2, h3 {
  font-family: "Audiowide", Arial, sans-serif;
  margin: 0;
  font-weight: normal;
}

#brand {
  margin-bottom: 1.61803399rem;
}

#title {
  font-size: 2.6180339927953202rem;
  text-transform: lowercase;
  letter-spacing: 0.05em;
}

#description {
  text-transform: uppercase;
  font-weight: bold;
}
~~~~

We space the letters out just a bit so that the description is the same
width as the title, just like on the real Monotron.

The next thing we need to do is lay out the control panels. The best
tool for this job is the [flexbox layout mode][]. If you're not familiar
with flexbox, it's a new layout mode in CSS3 that automatically adapts
to the number of columns or rows you have. Basically, it renders CSS
layout frameworks obsolete. The main downside is that there's no
standard CSS directive for enabling it yet. I used [LESS][] and [this
Gist][] to take care of the prefixes for me.

~~~~ {.css}
#controls {
  .flex-display;

  .panel {
    padding: @size-base;
    .flex(1);

    h2 {
      text-align: center;
      margin-bottom: @size-base;
    }

    label {
      text-transform: lowercase;
      font-weight: bold;
    }

    .knobs {
      .flex-display;

      .knob {
        .flex(1);
        text-align: center;

        div {
          text-align: center;
          width: 100% !important;
          margin-bottom: @size-small;
        }
      }
    }

    &:first-child {
      text-align: center;
      .flex-display;
      .justify-content(center);
      .align-items(flex-end);

      select {
        margin-bottom: @size-small;
      }
    }
  }
}
~~~~

There's a lot going on here, but most important is the `.flex(1);`
directives. This tells the browser that each `.panel` should take up one
column, and each column should take up equal space. No need to worry
about manually specifying widths, floats, etc. -- it's all taken care of
for you.

The knobs are also aligned with flexbox. In the VCO control panel,
there's only one knob, but since we're using flexbox, it's automatically
aligned correctly.

Of course, we haven't actually added the knobs yet. The most popular
knob library is [jQuery knob][], but actually, it's not the best option.
The best knob library is [Jim Knopf][], which uses SVG instead of
canvas. This has two advantages: it scales beautifully and it can be
styled (mostly) with CSS. I ended up using a modified version of "preset
2":

~~~~ {.javascript}
Ui.P2 = function() {
};

Ui.P2.prototype = Object.create(Ui.prototype);

Ui.P2.prototype.createElement = function() {
  "use strict";
  Ui.prototype.createElement.apply(this, arguments);
  this.addComponent(new Ui.Arc({
    arcWidth: this.width / 10
  }));

  this.addComponent(new Ui.Pointer(this.merge(this.options, {
    type: 'Rect',
    pointerWidth: this.width / 10
  })));

  this.merge(this.options, {arcWidth: this.width / 10});
  var arc = new Ui.El.Arc(this.options);
  arc.setAngle(this.options.anglerange);
  this.el.node.appendChild(arc.node);
  this.el.node.setAttribute("class", "p2");
};
~~~~

~~~~ {.css}
.p2 path {
  stroke: none;
  fill: @text-color;
  stroke-weight: .1;
}

.p2 path:first-child {
  fill: darken(@bg-color, 5%);
}

.p2 rect {
  fill: @text-color;
}
~~~~

And then initialize the knobs when the page is finished loading:

~~~~ {.coffee}
$ ->
  $('.knob input').each (i, knob) ->
    knopf = new Knob(knob, new Ui.P2())
~~~~

The Ribbon Keyboard
-------------------

At this point, we've got the audio circuit and the control panel. The
remaining component is the ribbon keyboard. Looking at the Monotron's
keyboard, my first instinct was to use canvas. However, canvas is not
the right approach here, because it's not scalable[^3]. I just used
(dynamically-generated) HTML and CSS for the keyboard interface:

~~~~ {.coffee}
noteToFrequency = (note) ->
  Math.pow(2, (note - 69) / 12) * 440.0

class RibbonKeyboard
  constructor: (@$el, @monotron) ->
    @minNote = 57
    $ul = $('<ul>')
    for note in [1..18]
      $key = $('<li>')
      if note in [2, 5, 7, 10, 12, 14, 17]
        $key.addClass 'accidental'
        $key.width (@$el.width() / 20)
        $key.css 'left', "-#{$key.width() / 2}px"
        $key.css 'margin-right', "-#{$key.width()}px"
      else if note in [1, 18]
        $key.width (@$el.width() / 20)
      else
        $key.width (@$el.width() / 10)
      $ul.append $key
    @$el.append $ul

    @mouseDown = false
    $ul.mousedown (e) =>
      @mouseDown = true
      @click(e)
    $ul.mouseup (e) =>
      @mouseDown = false
      @monotron.noteOff()
    $ul.mousemove @click

  click: (e) =>
    return unless @mouseDown
    offset =  e.pageX - @$el.offset().left
    ratio = offset / @$el.width()
    min = noteToFrequency @minNote
    max = noteToFrequency (@minNote + 18)
    @monotron.noteOn ratio * (max - min) + min
~~~~

Basically, the `RibbonKeyboard` constructor creates 18 keys, manually
setting the right width for each one. If the note is a "white"
(accidental) key, it adds the `.accidental` class and a negative margin
so that it overlaps with the next key.

To emulate the Monotron's ribbon keyboard, we listen for `mousedown`,
`mouseup`, and `mousemove` events. This way, we can trigger new notes
whenever the user drags the mouse across the keyboard.

The interesting thing here is the `click` event handler. It calculates
where the user has clicked on the keyboard as a ratio between 0.0 and
1.0. It then rescales this into a musical frequency with the
`noteToFrequency` function. By default, `@minNote` is set to 57, which
means that C on the keyboard will correspond to middle C (MIDI note 60).

Now to make the keyboard look like the real thing, check out this CSS:

~~~~ {.css}
#keyboard {
  .box-sizing(border-box);
  .box-shadow(inset 0 0 @size-base fade(@text-color, 10%));
  background-color: darken(@bg-color, 8%);
  border-left: @size-base solid lighten(@bg-color, 10%);
  border-right: @size-base solid lighten(@bg-color, 10%);
  border-top: @size-base solid darken(@bg-color, 5%);
  border-bottom: @size-base solid lighten(@bg-color, 5%);
  height: 7rem;

  ul {
    margin: 0;
    padding: 0;
    list-style: none;
    width: 100%;
    height: 100%;

    li {
      float: left;
      height: 100%;
      border-right: 1px solid @text-color;
      position: relative;
      .box-sizing(border-box);

      &.accidental {
        background-color: @text-color;
        height: 70%;
      }

      &:last-child {
        border: none;
      }
    }
  }
}
~~~~

The cool thing here is the border around the keyboard, which makes it
look like the Monotron has some depth. When you specify thick borders of
different colors, they intersect at a 45 degree angle. With the right
shades of grey, we can create a fake 3D effect.

![Fake 3D with CSS Borders][]

Connecting the Components
-------------------------

Now we have all of the components we need to build a Monotron: the audio
circuit, the control panel, and the keyboard. The only thing that
remains is connecting these components together. First, let's set up the
audio and the keyboard:

~~~~ {.coffee}
$ ->
  audioContext = new (AudioContext ? webkitAudioContext)()
  window.monotron = new Monotron(audioContext)
  masterGain = audioContext.createGain()
  masterGain.gain.value = 0.7 # to prevent clipping
  masterGain.connect audioContext.destination
  monotron.connect masterGain

  keyboard = new RibbonKeyboard($('#keyboard'), monotron)
~~~~

We create a new `AudioContext` (keeping in mind that current browsers
name it differently), a new `Monotron` audio circuit, and the
`masterGain` node. The `masterGain` node is important because it
prevents the audio from exceeding the maximum value of +/-1.0. If the
audio did exceed +/-1.0, it would result in distortion known as
*clipping*. After connecting these nodes together, we create a new
`RibbonKeyboard` and connect it to the audio circuit.

Now you should be able to play some notes with the keyboard. Right now,
the sound isn't so hot. To fix that, we need to hook up the control
panel. There's one complication: audio parameters should be adjusted on
a logarithmic scale (because that's how our ears work), but the knobs
only provide a linear scale. We'll need to override the knobs'
`.changed` method to accomodate this:

~~~~ {.coffee}
  # ... rest of $(document).ready callback ...
  params =
    rate:
      param: monotron.lfo.frequency
      min: 0.001
      max: 900.0
      scale: 1.1
    int:
      param: monotron.lfoGain.gain
      min: 0.5
      max: 500.0
    cutoff:
      param: monotron.vcf.frequency
      min: 0.001
      max: 900.0
      scale: 1.03
    peak:
      param: monotron.vcf.Q
      min: 0.001
      max: 1000.0
      scale: 1.10

  knopfs = []
  $('.knob input').each (i, knob) ->
    knopf = new Knob(knob, new Ui.P2())
    knopfs.push knopf
    param = params[knob.id]
    if param?
      knopf.changed = ->
        Knob.prototype.changed.apply this, arguments
        # convert to log scale
        scale = param.scale ? 1.05
        ratio = Math.pow(scale, @value) / Math.pow(scale, @settings.max)
        value = ratio * (param.max - param.min) + param.min
        param.param.setValueAtTime value, audioContext.currentTime
    else if knob.id == "pitch"
      knopf.changed = ->
        Knob.prototype.changed.apply this, arguments
        keyboard.minNote = parseInt @value
~~~~

So first we define a data structure that specifies which `AudioParam`
the knob should control, the range of possible values, and how sensitive
the knob is. Then when we initialize the knob, we override the
`.changed` callback to actually change the corresponding `AudioParam`.

The pitch knob isn't controlling an `AudioParam`, so it's a special
case. It adjusts the minimum note on the keyboard.

Next we'll hook up the modulation router. If it's set to "Standby", the
LFO will be disabled. Otherwise, the LFO will modulate either the VCO
frequency ("Pitch") or the VCF cutoff frequency ("Cutoff").

~~~~ {.coffee}
  # ... rest of $(document).ready callback ...
  $('#mod').change (e) ->
    target = $(this).find(":selected").val()
    monotron.lfoGain.disconnect()
    if target is "Pitch"
      monotron.lfoGain.connect monotron.vco.frequency
    else if target is "Cutoff"
      monotron.lfoGain.connect monotron.vcf.frequency
~~~~

Finally, we'll specify the initial "patch" -- that is, the default
Monotron parameters:

~~~~ {.coffee}
  # ... rest of $(document).ready callback ...
  # the initial "patch"
  $("#pitch").val 57
  $("#rate").val 46
  $("#int").val 97
  $("#cutoff").val 72
  $("#peak").val 57
  $("#mod").val "Pitch"

  knopfs.forEach (knopf) ->
    knopf.changed 0
~~~~

The last thing is to manually call the `.changed` method on the knobs so
that the synth updates with the new values. Hopefully, you now have
[something like this][the demo]!

Conclusion
----------

Alright, at this point you've learned how to build a Monotron in
Javascript. However, if you've used [a real Monotron][Monotron], you may
be a bit disappointed with the way this one sounds. The reason is
because the real Monotron uses an [MS-20][] analog filter. This filter
has a signature resonance that just isn't there when using the Web Audio
API's `BiquadFilter`. However, all is not lost. The analog filter can be
emulated with a custom `ScriptProcessorNode`, and I'll show you how to
do this in an upcoming post.

[^1]: Normally, I would have the noteOn method accept a MIDI note number
    as its required parameter, but since the Monotron's ribbon keyboard
    doesn't do separate notes, I decided the noteOn method should just
    accept the raw frequency.

[^2]: I use LESS to [calculate this automatically][].

[^3]: Canvas isn't scalable by default, but if you redraw whenever the
    window is resized, you can make it seem like it is.

  [Korg Monotron synthesizer]: https://lh3.googleusercontent.com/-IB3Rw79rchE/Uf2tCgK4LyI/AAAAAAAAxvk/WT5SFo6O8Ug/s0/kor-monotron_3.jpg
  [Monotron]: http://www.amazon.com/dp/B003DX96TW/
  [the demo]: http://noisehack.com/monotron/
  [the code on GitHub]: https://github.com/zacharydenton/monotron
  [Monotron block diagram]: https://lh6.googleusercontent.com/-XqwhLdsOnu8/Uf2tCqvJQtI/AAAAAAAAxuU/X_IIwkkIviA/s0/monotron_Block_diagram+%25281%2529.jpg
  [a fairly simple synthesizer]: https://lh3.googleusercontent.com/-PqNb9yqvPxQ/Uf2tCpIWLgI/AAAAAAAAxuc/AN95hjSJBzI/s0/monotron_sch+%25281%2529.jpg
  [theremin]: https://en.wikipedia.org/wiki/Theremin
  [Pixeur]: http://www.veign.com/application.php?appid=107
  [Audiowide]: http://www.google.com/fonts/specimen/Audiowide
  [flexbox layout mode]: https://developer.mozilla.org/en-US/docs/Web/Guide/CSS/Flexible_boxes
  [LESS]: http://lesscss.org/
  [this Gist]: https://gist.github.com/jayj/4012969
  [jQuery knob]: http://anthonyterrien.com/knob/
  [Jim Knopf]: https://github.com/eskimoblood/jim-knopf
  [Fake 3D with CSS Borders]: https://lh3.googleusercontent.com/-KZdscuCzv1g/Uf8XeC1r_BI/AAAAAAAAxwA/9Ug5scl7TUI/s0/Capture2.jpg
  [MS-20]: http://www.amazon.com/dp/B00B5SKWBS/
  [calculate this automatically]: https://github.com/zacharydenton/monotron/blob/master/css/preboot.less#L45
