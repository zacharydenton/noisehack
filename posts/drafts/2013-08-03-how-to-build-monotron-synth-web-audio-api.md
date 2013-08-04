---
title: How to Build a Monotron Synth with the Web Audio API
excerpt: Recreate the Korg Monotron synthesizer with JavaScript and the Web Audio API.
---

![Korg Monotron synthesizer][]

The [Monotron][] is an awesome little analog synth by Korg. In this
post, you'll learn how to recreate the Monotron with the Web Audio API.

<!--more-->

Overview
--------

![Monotron block diagram][]

The Monotron is [a fairly simple synthesizer][], consisting of a
sawtooth oscillator (VCO), an LFO, and a lowpass filter (VCF). It's
monophonic, which means that only one note can be played at a time.

The Monotron's ribbon keyboard is interesting: the transitions between notes
are seamless, so by sweeping your finger across the keyboard you get a
theremin-like continuous change in pitch. Wiggling your finger back and forth
quickly produces a cool vibrato effect.

## The Audio Circuit

Let's get started by implementing the core audio circuit.
We'll use an `OscillatorNode` for the VCO and LFO and a
`BiquadFilterNode` for the VCF.

```coffeescript
<core audio circuit>
```

## The Interface

At this point, we have code that generates sound, but to make this
a useful instrument we need a user interface.

  [Korg Monotron synthesizer]: https://lh3.googleusercontent.com/-IB3Rw79rchE/Uf2tCgK4LyI/AAAAAAAAxvk/WT5SFo6O8Ug/s0/kor-monotron_3.jpg
  [Monotron]: http://www.amazon.com/dp/B003DX96TW/?tag=zacden-20
  [Monotron block diagram]: https://lh6.googleusercontent.com/-XqwhLdsOnu8/Uf2tCqvJQtI/AAAAAAAAxuU/X_IIwkkIviA/s0/monotron_Block_diagram+%25281%2529.jpg
  [a fairly simple synthesizer]: https://lh3.googleusercontent.com/-PqNb9yqvPxQ/Uf2tCpIWLgI/AAAAAAAAxuc/AN95hjSJBzI/s0/monotron_sch+%25281%2529.jpg
