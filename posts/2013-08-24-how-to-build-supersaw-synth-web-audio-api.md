---
title: How to Build a Supersaw Synthesizer with the Web Audio API
excerpt: Build a supersaw synth with CoffeeScript, LESS, and the Web Audio API.
---

![Web Audio Supersaw Synthesizer][]

If you've ever built a virtual synth before, you know that trying to
reproduce the analog sound is really hard[^1]. It's better to compete
where digital has a comparative advantage, like spawning hundreds of
oscillators dynamically. That's the essence of the supersaw synth: stack
a bunch of sawtooth oscillators on top of each other, each at a slightly
different frequency.

Here's [the demo][] and [the code][]. There are only two knobs: one to
control the number of oscillators; the other to control how out-of-tune
each oscillator is. It's simple, but it can make some cool sounds. Read
on if you want to learn how to build your own.

<!--more-->

Overview
--------

The supersaw sound first appeared in 1996 with the [Roland JP-8000
synth][]. The JP-8000's supersaw waveform is comprised of 7 detuned saw
waves. Later the [Access Virus TI][] came out with the hypersaw: 9
detuned sawtooth oscillators. The synth we're building today can do
hundreds of detuned oscillators.

We'll build this synth in three stages. The first thing we'll build is
what I like to call the "audio circuit": that is, the code that actually
makes noise. Second, we'll add a keyboard so we can play some notes, and
finally, we'll add a UI to make it look good (and a couple of knobs to
tweak the sound).

Audio Circuit
-------------

We're going to make this synthesizer polyphonic, meaning that multiple
notes can be played simultaneously (i.e., chords). The way I like to
implement this is to have a low-level class with the audio code needed
for a single note ("voice"), and a high-level class responsible for
managing these voices.

Let's start with the high-level class.

~~~~ {.coffee}
class Scissor
  constructor: (@context) ->
    @numSaws = 3
    @detune = 12
    @voices = []
    @output = @context.createGain()

  noteOn: (note, time) ->
    return if @voices[note]?
    time ?= @context.currentTime
    freq = noteToFrequency note
    voice = new ScissorVoice(@context, freq, @numSaws, @detune)
    voice.connect @output
    voice.start time
    @voices[note] = voice

  noteOff: (note, time) ->
    return unless @voices[note]?
    time ?= @context.currentTime
    @voices[note].stop time
    delete @voices[note]

  connect: (target) ->
    @output.connect target
~~~~

This is the high-level "synth object", responsible for handling `noteOn`
and `noteOff` messages. The way it does this is to keep track of a
`@voices` array. When a `noteOn` message is received, it converts the
`note` parameter ([the MIDI note number][]) to a frequency, then
constructs a `ScissorVoice` object with the appropriate parameters. It
stores a reference to this new voice in the `@voices` array, so it can
be used later when the `noteOff` method is called.

The conversion from MIDI note number to frequency looks like this:

~~~~ {.coffee}
noteToFrequency = (note) ->
  Math.pow(2, (note - 69) / 12) * 440.0
~~~~

What does this mean? Well, first of all, note number 69 corresponds to a
frequency of 440 Hz (A4), since 2^0/12^ \* 440.0 = 440 Hz. After that,
the notes follow a progression where each note is 2^1/12^ higher
frequency than the previous note[^2]. For example, note number 70 is
2^1/12^ \* 440.0 = 466.16 Hz.

Once the voice has been created, it's connected to the `@output` node,
and instructed to start playing at `time` (if the `time` parameter isn't
specified, the voice starts immediately).

Now we can write the `ScissorVoice` class.

~~~~ {.coffee}
class ScissorVoice
  constructor: (@context, @frequency, @numSaws, @detune) ->
    @output = @context.createGain()
    @maxGain = 1 / @numSaws
    @saws = []
    for i in [0...@numSaws]
      saw = @context.createOscillator()
      saw.type = saw.SAWTOOTH
      saw.frequency.value = @frequency
      saw.detune.value = -@detune + i * 2 * @detune / (@numSaws - 1)
      saw.start @context.currentTime
      saw.connect @output
      @saws.push saw

  start: (time) ->
    @output.gain.setValueAtTime @maxGain, time

  stop: (time) ->
    @output.gain.setValueAtTime 0, time
    setTimeout (=>
      # remove old saws
      @saws.forEach (saw) ->
        saw.disconnect()
    ), Math.floor((time - @context.currentTime) * 1000)

  connect: (target) ->
    @output.connect target
~~~~

As you can see, the class creates `@numSaws` sawtooth oscillators, with
the `detune` parameter spread from `-@detune` to `@detune`.

The `start` method just sets the `@output` gain to `@maxGain`.
`@maxGain` is set to `1 / @numSaws`, to keep the audio output in the
range [-1.0, 1.0]. When the `stop` method is called, the `@output` gain
is set to 0, and the oscillators are disconnected from the audio graph.
The garbage collector will eventually remove these disconnected nodes,
which saves CPU cycles.

At this point, you can test it out in the console:

~~~~ {.javascript}
var audioContext = new webkitAudioContext();
var scissor = new Scissor();
scissor.connect(audioContext.destination);
scissor.noteOn(60); // C4
scissor.noteOn(64); // E4
scissor.noteOn(67); // G4
~~~~

User Interface
--------------

We'll be building the interface with LESS. The first thing I like to do
when starting a new design is to define some additional LESS variables:

~~~~ {.css}
@phi:          1.61803399;
@size-nano:    unit(pow(@phi, -4), rem);
@size-micro:   unit(pow(@phi, -3), rem);
@size-tiny:    unit(pow(@phi, -2), rem);
@size-small:   unit(pow(@phi, -1), rem);
@size-base:    unit(pow(@phi,  0), rem);
@size-large:   unit(pow(@phi,  1), rem);
@size-huge:    unit(pow(@phi,  2), rem);
@size-massive: unit(pow(@phi,  3), rem);
@size-epic:    unit(pow(@phi,  4), rem);
~~~~

This is probably a bit strange if you haven't seen anything like this
before. It's called a [modular scale][]. Whenever I need a measurement
in the design, be it font size, margin, border size, or anything else, I
only use measurements from the scale. It keeps things visually
consistent and means I don't have to worry about whether the spacing
should be 3px or 4px.

Here's the markup we'll use for the synth UI:

~~~~ {.html}
<div id="scissor">
  <div id="controls">
    <div class="panel">
      <div class="knob">
        <input id="saws" type="range" min="1" max="15" data-width="62" data-height="62" data-angleOffset="220" data-angleRange="280" />
        <label>Num. Saws</label>
      </div>
    </div>
    <div class="title panel">
      <h1><a href="http://noisehack.com/">Scissor</a></h1>
      <p>Web Audio Supersaw Synthesizer</p>
    </div>
    <div class="panel">
      <div class="knob">
        <input id="detune" type="range" min="0" max="100" data-width="62" data-height="62" data-angleOffset="220" data-angleRange="280" />
        <label>Detune</label>
      </div>
    </div>
  </div>
  <div id="keyboard"></div>
</div>
~~~~

To get started on the CSS, we'll first import [normalize.css][],
[Preboot][], and these [flexbox mixins][]. If you haven't heard of it,
Preboot is basically "Bootstrap: The Good Parts". It has all the
Bootstrap LESS mixins and variables, without actually styling anything.
If you tend to override the default Bootstrap styles, I recommend giving
Preboot a try.

~~~~ {.css}
@import "normalize.less";
@import "preboot.less";
@import "flexbox.less";

@synth-color: #737373;
@header-color: #c30909;
~~~~

I decided to make the page background a radial gradient. Feel free to
change this if you'd prefer something more subtle.

~~~~ {.css}
html {
  width: 100%;
  height: 100%;
}

body {
  width: 100%;
  height: 100%;
  font-family: @font-family-base;
  #gradient.radial(@header-color, darken(@header-color, 34%));
  .user-select(none);
}
~~~~

To style the main body of the synth, use:

~~~~ {.css}
#scissor {
  #gradient.vertical(lighten(@synth-color, 30%), @synth-color);
  padding-left: @size-micro;
  padding-right: @size-micro;
  border-radius: @size-nano;
  .box-shadow(0 0 @size-base rgba(0,0,0,0.5));
}
~~~~

There was a recent post about [absolute centering with CSS][]. The
modern way to do this is to use [flexbox][][^3]. Here's how to center
the synth on the page with flexbox:

~~~~ {.css}
body {
  .flex-display;
  .align-items(center);
  .justify-content(center);
}
~~~~

No need to manually specify heights or widths---flexbox adapts to you,
not the other way around.

Here's the CSS for the `#controls` div:

~~~~ {.css}
#controls {
  padding: @size-base;
  margin-top: @size-small;
  .border-top-radius(@size-nano);
  .box-sizing(border-box);
  .flex-display;

  .panel {
    .flex(1);
    .justify-content(center);
    .align-items(center);
    text-align: center;

    .knob {
      div {
        text-align: center;
        width: 100% !important;
      }

      label {
        margin: 0;
        padding: 0;
        text-transform: uppercase;
        font-weight: 700;
        color: darken(@synth-color, 5%);
        text-shadow: 0 1px 0 lighten(@synth-color, 40%);
      }
    }

    &.title {
      .flex(2);
      .flex-display;
      .flex-direction(column);

      h1 {
        margin: 0;
        padding: 0;

        a {
          color: @header-color;
          text-shadow: 0 1px 0 lighten(@synth-color, 40%);
          font-size: @size-huge;
          line-height: 1;
          font-family: "Stalinist One", sans-serif;
          font-weight: 400;
          text-transform: uppercase;
          text-decoration: none;
        }
      }

      p {
        margin: 0;
        padding: 0;
        text-transform: uppercase;
        font-weight: 700;
        color: darken(@synth-color, 5%);
        text-shadow: 0 1px 0 lighten(@synth-color, 40%);
      }
    }
  }
}
~~~~

There are a few interesting things going on here. The text gets a 1px
`text-shadow` to make it look like it's engraved into the surface of the
synth. Also notice the `.flex(2);` directive in the `.panel.title` CSS.
That means it will take up two columns, while the other `.panel` divs
take up only one.

Keyboard
--------

We have the audio circuit and the synth control panel; now we need a
keyboard. I'm putting all the functionality into a single
`VirtualKeyboard` class. Instead of hard-coding functionality, it will
accept callbacks for `noteOn` and `noteOff` events, so that it can be
used with any instrument, not just the synth we're building today.

~~~~ {.coffee}
class VirtualKeyboard
  constructor: (@$el, params) ->
    @lowestNote = params.lowestNote ? 48
    @letters = params.letters ? "awsedftgyhujkolp;'".split ''
    @noteOn = params.noteOn ? (note) -> console.log "noteOn: #{note}"
    @noteOff = params.noteOff ? (note) -> console.log "noteOff: #{note}"
    @keysPressed = {}
    @render()
    @bindKeys()
    @bindMouse()

  _noteOn: (note) ->
    return if note of @keysPressed
    $(@$el.find('li').get(note - @lowestNote)).addClass 'active'
    @keysPressed[note] = true
    @noteOn note

  _noteOff: (note) ->
    return unless note of @keysPressed
    $(@$el.find('li').get(note - @lowestNote)).removeClass 'active'
    delete @keysPressed[note]
    @noteOff note
~~~~

We'll be using [Mousetrap][] to handle key events:

~~~~ {.coffee}
  bindKeys: ->
    for letter, i in @letters
      do (letter, i) =>
        Mousetrap.bind letter, (=>
          @_noteOn (@lowestNote + i)
        ), 'keydown'
        Mousetrap.bind letter, (=>
          @_noteOff (@lowestNote + i)
        ), 'keyup'

    Mousetrap.bind 'z', =>
      # shift one octave down
      @lowestNote -= 12
  
    Mousetrap.bind 'x', =>
      # shift one octave up
      @lowestNote += 12
~~~~

Note that pressing <kbd>z</kbd> shifts down an octave and pressing
<kbd>x</kbd> shifts up an octave. This works in the demo, too---if you
have a good sound system, try playing some basslines!

We also want the keys to respond if the user clicks on them:

~~~~ {.coffee}
  bindMouse: ->
    @$el.find('li').each (i, key) =>
      $(key).mousedown =>
        @_noteOn (@lowestNote + i)
      $(key).mouseup =>
        @_noteOff (@lowestNote + i)
~~~~

Once that's done, we want to add the CSS. I decided to go for a design
that looks like a cross between a computer keyboard and a piano
keyboard, similar to the one in Garageband:

~~~~ {.css}
@white-key: rgb(236, 236, 236);
@black-key: rgb(70, 70, 70);

.piano-key(@color) {
  background-color: @color;
  color: darken(@color, 30%);
  text-shadow: 0 1px 0 lighten(@color, 10%);
  border-top: @size-nano solid darken(@color, 10%);
  border-left: @size-tiny solid darken(@color, 15%);
  border-right: @size-tiny solid darken(@color, 15%);
  border-bottom: @size-micro solid darken(@color, 25%);
  .box-shadow(0 @size-micro @size-small rgba(0,0,0,0.5));

  &.active {
    .box-shadow(0 @size-nano @size-micro rgba(0,0,0,0.5));
    text-shadow: 0 1px 0 @color;
    #gradient.vertical(@color, darken(@color, 10%));
  }
}

#keyboard {
  cursor: pointer;

  ul {
    margin: 0 auto;
    padding: 0;
    list-style: none;

    li {
      float: left;
      width: @size-massive;
      height: @size-epic;
      text-transform: uppercase;
      font-style: italic;
      padding-left: @size-tiny;
      padding-bottom: @size-micro;
      margin-right: @size-nano;
      .box-sizing(border-box);
      .flex-display;
      .align-items(flex-end);
      .border-bottom-radius(@size-micro);
      .piano-key(@white-key);

      &.accidental {
        position: relative;
        margin-left: -@size-large;
        margin-right: -(@size-large + (@size-massive / 2));
        height: @size-massive;
        .piano-key(@black-key);
      }

      &:last-child {
        margin-right: 0;
      }
    }
  }
}
~~~~

The white and black keys have a lot of CSS in common, so I made a
`.piano-key` mixin to reduce repetition. This also means it's easy to
change the keyboard color; just change the values of `@white-key` and
`@black-key`.

Putting It Together
-------------------

That's it for the individual components; now it's time to instantiate
and connect them to create the finished synth:

~~~~ {.coffee}
$ ->
  audioContext = new (AudioContext ? webkitAudioContext)
  masterGain = audioContext.createGain()
  masterGain.gain.value = 0.7
  masterGain.connect audioContext.destination
  window.scissor = new Scissor(audioContext)
  scissor.connect masterGain

  keyboard = new VirtualKeyboard $("#keyboard"),
    noteOn: (note) ->
      scissor.noteOn note
    noteOff: (note) ->
      scissor.noteOff note

  setNumSaws = (numSaws) ->
    scissor.numSaws = numSaws

  setDetune = (detune) ->
    scissor.detune = detune

  sawsKnob = new Knob($("#saws")[0], new Ui.P2())
  sawsKnob.changed = ->
    Knob.prototype.changed.apply this, arguments
    setNumSaws @value
  $("#saws").val scissor.numSaws
  sawsKnob.changed 0

  detuneKnob = new Knob($("#detune")[0], new Ui.P2())
  detuneKnob.changed = ->
    Knob.prototype.changed.apply this, arguments
    setDetune @value
  $("#detune").val scissor.detune
  detuneKnob.changed 0
~~~~

Conclusion
----------

Even though the synth has only two knobs, it can produce some
interesting sounds. With 3-5 oscillators, and detune at 9 o'clock, you
get the classic 90s trance lead. With 20 oscillators, and detune just
above the minimum, you get something that starts off as a nice pluck
sound, but evolves into something else entirely when held for a while.

[^1]: With that said, we've come [pretty far][].

[^2]: Since there are 12 notes in an octave, this means that if you have
    a note, say, C4, and transpose it one octave to C5, you'll have
    doubled its frequency. For instance, A4 is 440 Hz, A5 is 880 Hz, A6
    is 1760 Hz, and so on.

[^3]: Granted, flexbox doesn't work in older browsers---but hey, neither
    does the Web Audio API.

  [Web Audio Supersaw Synthesizer]: https://lh3.googleusercontent.com/-nYuzrImKyNo/Ugq4z7OdQKI/AAAAAAAAx6A/euHfSzs7qQg/s0/scissor.PNG
  [the demo]: /scissor/
  [the code]: https://github.com/zacharydenton/scissor
  [Roland JP-8000 synth]: http://en.wikipedia.org/wiki/Roland_JP-8000#The_Supersaw
  [Access Virus TI]: http://en.wikipedia.org/wiki/Access_Virus
  [the MIDI note number]: http://www.phys.unsw.edu.au/jw/notes.html
  [modular scale]: http://alistapart.com/article/more-meaningful-typography
  [normalize.css]: http://necolas.github.io/normalize.css/
  [Preboot]: http://getpreboot.com/
  [flexbox mixins]: https://gist.github.com/jayj/4012969
  [absolute centering with CSS]: http://codepen.io/shshaw/full/gEiDt
  [flexbox]: https://developer.mozilla.org/en-US/docs/Web/Guide/CSS/Flexible_boxes
  [Mousetrap]: http://craig.is/killing/mice
  [pretty far]: http://www.u-he.com/cms/diva
