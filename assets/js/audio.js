// Web Audio synth for codenames sound feedback. No file deps for the synth
// tones — every effect is generated from oscillators + envelopes. The boo
// effect uses an mp3 file (priv/static/sounds/boo.mp3).

let ctx = null

function getCtx() {
  if (!ctx) {
    const Ctor = window.AudioContext || window.webkitAudioContext
    if (!Ctor) return null
    ctx = new Ctor()
  }
  if (ctx.state === "suspended") ctx.resume()
  return ctx
}

function tone({ freq, duration = 0.4, wave = "sine", volume = 0.25, attack = 0.005, delay = 0 }) {
  const c = getCtx()
  if (!c) return
  const osc = c.createOscillator()
  const gain = c.createGain()
  osc.type = wave
  osc.frequency.value = freq
  const t0 = c.currentTime + delay
  gain.gain.setValueAtTime(0.0001, t0)
  gain.gain.exponentialRampToValueAtTime(volume, t0 + attack)
  gain.gain.exponentialRampToValueAtTime(0.0001, t0 + duration)
  osc.connect(gain).connect(c.destination)
  osc.start(t0)
  osc.stop(t0 + duration + 0.05)
}

function chord(freqs, opts) {
  freqs.forEach((f) => tone({ ...opts, freq: f }))
}

function arpeggio(freqs, { interval = 0.09, ...opts }) {
  freqs.forEach((f, i) => tone({ ...opts, freq: f, delay: i * interval }))
}

function sweep({ from, to, duration = 0.4, wave = "sawtooth", volume = 0.2 }) {
  const c = getCtx()
  if (!c) return
  const osc = c.createOscillator()
  const gain = c.createGain()
  osc.type = wave
  const t0 = c.currentTime
  osc.frequency.setValueAtTime(from, t0)
  osc.frequency.exponentialRampToValueAtTime(to, t0 + duration)
  gain.gain.setValueAtTime(0.0001, t0)
  gain.gain.exponentialRampToValueAtTime(volume, t0 + 0.01)
  gain.gain.exponentialRampToValueAtTime(0.0001, t0 + duration)
  osc.connect(gain).connect(c.destination)
  osc.start(t0)
  osc.stop(t0 + duration + 0.05)
}

// Lazy-loaded HTMLAudioElement for the boo sample. Re-using a single element
// keeps memory low and avoids re-decoding on each play.
let booEl = null
function playBoo() {
  if (!booEl) {
    booEl = new Audio("/sounds/boo.mp3")
    booEl.preload = "auto"
    booEl.volume = 0.4
  }
  try {
    booEl.currentTime = 0
    booEl.play().catch(() => {})
  } catch (_) {}
}

// Heartbeat loops once a game gets tense. Once started it keeps playing
// until the game is won or restarted — even if the score temporarily un-tenses.
let heartbeatEl = null
let heartbeatActive = false

function ensureHeartbeat() {
  if (!heartbeatEl) {
    heartbeatEl = new Audio("/sounds/heartbeat.mp3")
    heartbeatEl.loop = true
    heartbeatEl.volume = 1.0
    heartbeatEl.preload = "auto"
  }
  return heartbeatEl
}

function startHeartbeat() {
  if (heartbeatActive) return
  heartbeatActive = true
  ensureHeartbeat().play().catch(() => {})
}

function stopHeartbeat() {
  if (!heartbeatActive && !heartbeatEl) return
  heartbeatActive = false
  if (heartbeatEl) {
    heartbeatEl.pause()
    heartbeatEl.currentTime = 0
  }
}

// "Close game" trigger — both teams have 3 or fewer cards remaining AND
// they're within 1 of each other. Generous on purpose so the heartbeat
// kicks in during the genuinely-tense endgame stretch.
function isCloseGame(red, blue) {
  return red <= 3 && blue <= 3 && Math.abs(red - blue) <= 1
}

const audio = {
  reveal(kind) {
    switch (kind) {
      case "red":
        chord([392.0, 493.88], { duration: 0.35, wave: "triangle", volume: 0.22 })
        break
      case "blue":
        chord([523.25, 659.25], { duration: 0.35, wave: "triangle", volume: 0.22 })
        break
      case "neutral":
        tone({ freq: 180, duration: 0.35, wave: "sine", volume: 0.25 })
        tone({ freq: 90, duration: 0.4, wave: "sine", volume: 0.2 })
        break
      case "assassin":
        sweep({ from: 220, to: 55, duration: 1.2, wave: "sawtooth", volume: 0.32 })
        chord([110, 130.81, 155.56], { duration: 1.4, wave: "triangle", volume: 0.18 })
        break
    }
  },
  win(_team, { prominent = false } = {}) {
    // ~9 second multi-phase celebration. All notes are scheduled via the
    // Web Audio clock (sample-accurate), not setTimeout.
    const v = prominent ? 0.42 : 0.34

    // Phase 1 — heralding fanfare rising up (0.0 – 1.0s)
    const fanfare = [523.25, 659.25, 783.99, 1046.5, 1318.51]
    fanfare.forEach((f, i) =>
      tone({ freq: f, delay: i * 0.1, duration: 0.4, wave: "triangle", volume: v })
    )
    // Brass chord landing under the top of the fanfare (0.5 – 1.5s)
    const brass = [523.25, 659.25, 783.99, 1046.5]
    brass.forEach((f) =>
      tone({ freq: f, delay: 0.5, duration: 1.0, wave: "sine", volume: v * 0.55 })
    )

    // Phase 2 — triumphant melodic line (1.5 – 3.7s)
    const melody = [
      { freq: 783.99, delay: 1.6, duration: 0.25 },
      { freq: 880.0,  delay: 1.88, duration: 0.25 },
      { freq: 987.77, delay: 2.16, duration: 0.25 },
      { freq: 1046.5, delay: 2.44, duration: 0.5 },
      { freq: 783.99, delay: 3.0,  duration: 0.25 },
      { freq: 1318.51, delay: 3.28, duration: 0.5 },
    ]
    melody.forEach((n) => tone({ ...n, wave: "triangle", volume: v * 0.95 }))

    // Phase 3 — sustained crescendo chord underneath (3.8 – 5.5s)
    const swell = [261.63, 392.0, 523.25, 659.25, 783.99, 1046.5]
    swell.forEach((f) =>
      tone({ freq: f, delay: 3.8, duration: 1.7, wave: "sine", volume: v * 0.32 })
    )

    // Phase 4 — sparkle cascade tumbling down (5.5 – 7.0s)
    const sparkle = [2093, 1760, 1397, 1175, 1046.5, 880, 698.46, 587.33]
    sparkle.forEach((f, i) =>
      tone({
        freq: f,
        delay: 5.5 + i * 0.13,
        duration: 0.18,
        wave: "triangle",
        volume: v * 0.65,
      })
    )

    // Phase 5 — massive final stab, full chord across octaves (7.0 – 9.0s)
    const finalChord = [
      130.81, 196.0, 261.63, 329.63, 392.0, 523.25, 659.25, 783.99, 1046.5, 1318.51,
    ]
    finalChord.forEach((f) =>
      tone({ freq: f, delay: 7.0, duration: 1.9, wave: "sine", volume: v * 0.32 })
    )
    // Triangle layer on top for shimmer
    ;[1046.5, 1318.51, 1567.98, 2093].forEach((f) =>
      tone({ freq: f, delay: 7.0, duration: 1.9, wave: "triangle", volume: v * 0.28 })
    )

    // Stolen-win extras — extra cackling sparkle right after the fanfare
    // and an extra octave layer on the final stab.
    if (prominent) {
      const cackle = [1567.98, 1318.51, 1567.98, 1318.51, 1567.98, 1318.51]
      cackle.forEach((f, i) =>
        tone({
          freq: f,
          delay: 0.6 + i * 0.07,
          duration: 0.1,
          wave: "square",
          volume: 0.2,
        })
      )
      tone({ freq: 2637.02, delay: 7.0, duration: 1.9, wave: "triangle", volume: v * 0.35 })
    }
  },
  endTurn(newTeam) {
    // Quick herald in the incoming team's color
    if (newTeam === "red") {
      chord([329.63, 392.0], { duration: 0.22, wave: "triangle", volume: 0.18 })
    } else if (newTeam === "blue") {
      chord([440.0, 523.25], { duration: 0.22, wave: "triangle", volume: 0.18 })
    }
  },
  shuffle() {
    arpeggio([880, 740, 587, 494, 392], {
      interval: 0.04,
      duration: 0.12,
      wave: "triangle",
      volume: 0.18,
    })
  },
  boo: playBoo,
}

window.addEventListener("phx:card_revealed", (e) => {
  const { kind, guessing_team, winner } = e.detail

  audio.reveal(kind)

  const wrongTeam =
    (kind === "red" || kind === "blue") && kind !== guessing_team

  // If the wrong-team pick *handed* the other team the win, skip the boo —
  // the over-the-top win fanfare carries the moment instead.
  const stolenWin = wrongTeam && !!winner

  if (wrongTeam && !stolenWin) {
    setTimeout(() => audio.boo(), 350)
  }

  if (winner) {
    setTimeout(() => audio.win(winner, { prominent: stolenWin }), 700)
  }
})

window.addEventListener("phx:turn_ended", (e) => {
  audio.endTurn(e.detail.current_turn)
})

window.addEventListener("phx:tension_check", (e) => {
  const { red, blue, winner } = e.detail
  if (winner) {
    stopHeartbeat()
    return
  }
  // Once started, the heartbeat keeps going until winner/restart — we only
  // ever flip it ON here, never off based on score un-tensing.
  if (isCloseGame(red, blue)) {
    startHeartbeat()
  }
})

window.addEventListener("phx:game_restarted", () => {
  stopHeartbeat()
  audio.shuffle()
})

export default audio
