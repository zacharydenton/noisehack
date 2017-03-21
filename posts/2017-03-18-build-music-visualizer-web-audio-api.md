---
title: Build a Music Visualizer with the Web Audio API
excerpt: Basics of music visualization using the Web Audio API.
---

If you've ever wondered how music visualizers like Milkdrop are made, this post is for you. We'll start with simple visualizations using the Canvas API and move on to more sophisticated visualizations with WebGL shaders.

<!--more-->

## Waveform Visualization with the Canvas API

The first thing you need to make an audio visualizer is some audio. Today we have two options: a saw sweep from A3 to A6 and a song I made (a reconstruction of the track ["Zero Centre" by Pye Corner Audio](https://www.beatport.com/track/zero-centre-original-mix/4853537)).

<p><button class="play-btn">Saw Sweep</button><button class="song-btn">Play Song</button></p>

The second thing all audio visualizers need is a way to access the audio data. The Web Audio API provides the AnalyserNode for this purpose. In addition to providing the raw waveform (aka time domain) data, it provides methods for accessing the audio spectrum (aka frequency domain) data. Using the AnalyserNode is simple: create a `TypedArray` of length `AnalyserNode.frequencyBinCount` and then call the method `AnalyserNode.getFloatTimeDomainData` to populate the array with the current waveform data.

~~~~ {.javascript}
const analyser = audioContext.createAnalyser()
masterGain.connect(analyser)

const waveform = new Float32Array(analyser.frequencyBinCount)
analyser.getFloatTimeDomainData(waveform)
~~~~

At this point, the `waveform` array will contain values from -1 to 1 corresponding to the audio waveform playing through the `masterGain` node. This is just a snapshot of whatever's currently playing. In order to be useful, we need to update the array periodically. It's a good idea to update the array in a `requestAnimationFrame` callback.

~~~~ {.javascript}
;(function updateWaveform() {
  requestAnimationFrame(updateWaveform)
  analyser.getFloatTimeDomainData(waveform)
})()
~~~~

The `waveform` array will now be updated 60 times per second, which brings us to the final ingredient: some drawing code. In this example, we simply plot the waveform on the y-axis like an oscilloscope.

~~~~ {.javascript}
const scopeCanvas = document.getElementById('oscilloscope')
scopeCanvas.width = waveform.length
scopeCanvas.height = 200
const scopeContext = scopeCanvas.getContext('2d')

;(function drawOscilloscope() {
  requestAnimationFrame(drawOscilloscope)
  scopeContext.clearRect(0, 0, scopeCanvas.width, scopeCanvas.height)
  scopeContext.beginPath()
  for (let i = 0; i < waveform.length; i++) {
    const x = i
    const y = (0.5 + waveform[i] / 2) * scopeCanvas.height;
    if (i == 0) {
      scopeContext.moveTo(x, y)
    } else {
      scopeContext.lineTo(x, y)
    }
  }
  scopeContext.stroke()
})()
~~~~

<p><canvas id="oscilloscope"></canvas></p>
<p><button class="play-btn">Saw Sweep</button><button class="song-btn">Play Song</button></p>

Try clicking the "Saw Sweep" button multiple times to see how the waveform responds.

## Spectrum Visualization with the Canvas API

The AnalyserNode also provides data on the frequencies currently present in the audio. It runs an [FFT](https://en.wikipedia.org/wiki/Fast_Fourier_transform) on the waveform data and exposes these values as an array. In this case we'll request the data as a `Uint8Array` because values in the range 0-255 are exactly what we need when performing Canvas pixel manipulation.

~~~~ {.javascript}
const spectrum = new Uint8Array(analyser.frequencyBinCount)
;(function updateSpectrum() {
  requestAnimationFrame(updateSpectrum)
  analyser.getByteFrequencyData(spectrum)
})()
~~~~

Similar to the `waveform` array, the `spectrum` array will now be updated 60 times per second with the current audio spectrum. The values correspond to the volume of a given slice of the spectrum, in order from low frequencies to high frequencies. Let's see how to use this data to create a visualization known as a [spectrogram](https://en.wikipedia.org/wiki/Spectrogram).

~~~~ {.javascript}
const spectroCanvas = document.getElementById('spectrogram')
spectroCanvas.width = spectrum.length
spectroCanvas.height = 200
const spectroContext = spectroCanvas.getContext('2d')
let spectroOffset = 0

;(function drawSpectrogram() {
  requestAnimationFrame(drawSpectrogram)
  const slice = spectroContext.getImageData(0, spectroOffset, spectroCanvas.width, 1)
  for (let i = 0; i < spectrum.length; i++) {
    slice.data[4 * i + 0] = spectrum[i] // R
    slice.data[4 * i + 1] = spectrum[i] // G
    slice.data[4 * i + 2] = spectrum[i] // B
    slice.data[4 * i + 3] = 255         // A
  }
  spectroContext.putImageData(slice, 0, spectroOffset)
  spectroOffset += 1
  spectroOffset %= spectroCanvas.height
})()
~~~~

<p><canvas id="spectrogram"></canvas></p>
<p><button class="play-btn">Saw Sweep</button><button class="song-btn">Play Song</button></p>

I've found the spectrogram to be one of the most useful tools for analyzing audio, for instance to find out what chord is being played or to debug a synth patch that doesn't sound right. Spectrograms are also good for finding [easter eggs](https://en.wikipedia.org/wiki/Windowlicker#Hidden_images)!

## Visualizations with WebGL Shaders

My favorite computer graphics technique is [fullscreen pixel shaders](https://en.wikipedia.org/wiki/Shader) with WebGL. Normally several pixel shaders are used in combination with 3D geometry to render a scene, but today we're going to skip the geometry and render the entire scene using a single pixel (aka fragment) shader. There's a bit more boilerplate compared to the Canvas API, but the end result is well worth it.

To start, we need to draw a rectangle (aka quad) covering the entire screen. This is the surface upon which the fragment shader will be drawn.

~~~~ {.javascript}
function initQuad(gl) {
  const vbo = gl.createBuffer()
  gl.bindBuffer(gl.ARRAY_BUFFER, vbo)
  const vertices = new Float32Array([-1, -1, 1, -1, -1, 1, 1, 1])
  gl.bufferData(gl.ARRAY_BUFFER, vertices, gl.STATIC_DRAW)
  gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0)
}

function renderQuad(gl) {
  gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4)
}
~~~~

Now that we have the fullscreen quad (technically it's two half-screen triangles), we need a shader program. Here's a function that takes a vertex shader and a fragment shader, and returns a compiled shader program.

~~~~ {.javascript}
function createShader(gl, vertexShaderSrc, fragmentShaderSrc) {
  const vertexShader = gl.createShader(gl.VERTEX_SHADER)
  gl.shaderSource(vertexShader, vertexShaderSrc)
  gl.compileShader(vertexShader)
  if (!gl.getShaderParameter(vertexShader, gl.COMPILE_STATUS)) {
    throw new Error(gl.getShaderInfoLog(vertexShader))
  }

  const fragmentShader = gl.createShader(gl.FRAGMENT_SHADER)
  gl.shaderSource(fragmentShader, fragmentShaderSrc)
  gl.compileShader(fragmentShader)
  if (!gl.getShaderParameter(fragmentShader, gl.COMPILE_STATUS)) {
    throw new Error(gl.getShaderInfoLog(fragmentShader))
  }

  const shader = gl.createProgram()
  gl.attachShader(shader, vertexShader)
  gl.attachShader(shader, fragmentShader)
  gl.linkProgram(shader)
  gl.useProgram(shader)

  return shader
}
~~~~

The vertex shader for this visualization is extremely simple. It just passes through the vertex position without modifying it.

~~~~ {.glsl #vertex-shader}
attribute vec2 position;

void main(void) {
  gl_Position = vec4(position, 0, 1);
}
~~~~

The fragment shader is a lot more interesting. We'll start with [this shader by Danguafer](https://www.shadertoy.com/view/XsXXDn) and make a few strategic modifications so it responds to the audio.

~~~~ {.glsl #fragment-shader}
precision mediump float;

uniform float time;
uniform vec2 resolution;
uniform sampler2D spectrum;

void main(void) {
  vec3 c;
  float z = 0.1 * time;
  vec2 uv = gl_FragCoord.xy / resolution;
  vec2 p = uv - 0.5;
  p.x *= resolution.x / resolution.y;
  float l = 0.2 * length(p);
  for (int i = 0; i < 3; i++) {
    z += 0.07;
    uv += p / l * (sin(z) + 1.0) * abs(sin(l * 9.0 - z * 2.0));
    c[i] = 0.01 / length(abs(mod(uv, 1.0) - 0.5));
  }
  float intensity = texture2D(spectrum, vec2(l, 0.5)).x;
  gl_FragColor = vec4(c / l * intensity, time);
}
~~~~

The key is multiplying the output color with the spectrum intensity. The other difference is that we scale `l` by 0.2 because most of the audio is in the first 20% of the spectrum texture.

What is the spectrum texture, exactly? It's the `spectrum` array from before, copied into a 1024x1 image. Here's how to accomplish that (the same technique could be used for the waveform data):

~~~~ {.javascript}
function createTexture(gl) {
  const texture = gl.createTexture()
  gl.bindTexture(gl.TEXTURE_2D, texture)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
  return texture
}

function copyAudioDataToTexture(gl, audioData, textureArray) {
  for (let i = 0; i < audioData.length; i++) {
    textureArray[4 * i + 0] = audioData[i] // R
    textureArray[4 * i + 1] = audioData[i] // G
    textureArray[4 * i + 2] = audioData[i] // B
    textureArray[4 * i + 3] = 255          // A
  }
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, audioData.length, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE, textureArray)
}
~~~~

With all of that out of the way, we're finally ready to draw the visualization. First, we initialize the canvas and compile the shader.

~~~~ {.javascript}
const fragCanvas = document.getElementById('fragment')
fragCanvas.width = fragCanvas.parentNode.offsetWidth
fragCanvas.height = fragCanvas.width * 0.75
const gl = fragCanvas.getContext('webgl') || fragCanvas.getContext('experimental-webgl')
const vertexShaderSrc = document.getElementById('vertex-shader').textContent
const fragmentShaderSrc = document.getElementById('fragment-shader').textContent
const fragShader = createShader(gl, vertexShaderSrc, fragmentShaderSrc)
~~~~

Next, we initialize the shader variables: `position`, `time`, `resolution`, and the one we're most interested in, `spectrum`.


~~~~ {.javascript}
const fragPosition = gl.getAttribLocation(fragShader, 'position')
gl.enableVertexAttribArray(fragPosition)
const fragTime = gl.getUniformLocation(fragShader, 'time')
gl.uniform1f(fragTime, audioContext.currentTime)
const fragResolution = gl.getUniformLocation(fragShader, 'resolution')
gl.uniform2f(fragResolution, fragCanvas.width, fragCanvas.height)
const fragSpectrumArray = new Uint8Array(4 * spectrum.length)
const fragSpectrum = createTexture(gl)
~~~~

Now that the variables are set up, we initialize the fullscreen quad and start the render loop. On every frame, we update the `time` variable and the `spectrum` texture, and render the quad.

~~~~ {.javascript}
initQuad(gl)

;(function renderFragment() {
  requestAnimationFrame(renderFragment)
  gl.uniform1f(fragTime, audioContext.currentTime)
  copyAudioDataToTexture(gl, spectrum, fragSpectrumArray)
  renderQuad(gl)
})()
~~~~

<p><canvas id="fragment"></canvas></p>
<p><button class="play-btn">Saw Sweep</button><button class="song-btn">Play Song</button></p>

As you can see, fullscreen fragment shaders are quite powerful. For more ideas, spend some time exploring [Shadertoy](https://www.shadertoy.com/). [The Book of Shaders](https://thebookofshaders.com/) is another excellent resource.

<script src="/js/build-music-visualizer-web-audio-api.js"></script>
