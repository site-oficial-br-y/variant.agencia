'use client'
import { useEffect, useRef, useState } from 'react'
import Link from 'next/link'

const BEST_KEY = 'honkponk_surf_best'

type Phase = 'menu' | 'playing' | 'over'

interface Popup { text: string; x: number; y: number; t: number; big: boolean }
interface Part { x: number; y: number; vx: number; vy: number; life: number; size: number }

const clamp = (v: number, a: number, b: number) => Math.max(a, Math.min(b, v))

export default function SurfPage() {
  const canvasRef = useRef<HTMLCanvasElement>(null)
  const [phase, setPhase] = useState<Phase>('menu')
  const [finalScore, setFinalScore] = useState(0)
  const [best, setBest] = useState(0)
  const [isRecord, setIsRecord] = useState(false)
  const [wipeReason, setWipeReason] = useState('')
  const phaseRef = useRef<Phase>('menu')
  const startFn = useRef<() => void>(() => {})

  useEffect(() => { phaseRef.current = phase }, [phase])

  useEffect(() => {
    document.title = 'Honk Surf 🏄 — Honk Ponk'
    setBest(Number(localStorage.getItem(BEST_KEY) || 0))

    const canvas = canvasRef.current
    if (!canvas) return
    const ctx = canvas.getContext('2d')
    if (!ctx) return

    let W = 0, H = 0, raf = 0
    let last = performance.now()
    const key = { up: false, down: false }
    const ptr = { active: false, up: false, down: false }
    let bestLocal = Number(localStorage.getItem(BEST_KEY) || 0)

    const g = {
      h: 0.45, vh: 0, speed: 6, lead: 0.7, waveSpeed: 5,
      score: 0, combo: 1, comboT: 0, t: 0, snapCd: 0, lastDir: 0,
      air: 0, airDur: 0.8, shake: 0, tubeT: 0,
      barrelIn: 0, barrelWarn: 0, nextBarrel: 9,
      popups: [] as Popup[], parts: [] as Part[],
    }

    function resize() {
      const dpr = Math.min(window.devicePixelRatio || 1, 2)
      W = window.innerWidth
      H = window.innerHeight
      canvas!.width = W * dpr
      canvas!.height = H * dpr
      canvas!.style.width = W + 'px'
      canvas!.style.height = H + 'px'
      ctx!.setTransform(dpr, 0, 0, dpr, 0, 0)
    }
    resize()
    window.addEventListener('resize', resize)

    const bottomY = () => H * 0.92
    const px = () => W * 0.44
    const crestY = (x: number) =>
      H * 0.26 + (x / W) * H * 0.28 + Math.sin(x * 0.006 + g.t * 2) * 6 + Math.sin(x * 0.013 - g.t * 3.1) * 3
    const playerY = () => {
      const c = crestY(px())
      return bottomY() - g.h * (bottomY() - c)
    }
    const foamX = () => px() - 40 - g.lead * W * 0.32

    function popup(text: string, big: boolean) {
      g.popups.push({ text, x: px(), y: playerY() - 50, t: 0, big })
    }

    function sprayBurst(n: number) {
      const y = playerY()
      for (let i = 0; i < n; i++) {
        g.parts.push({
          x: px() + (Math.random() - 0.5) * 20, y: y + 8,
          vx: -60 - Math.random() * 160, vy: -120 - Math.random() * 180,
          life: 0.5 + Math.random() * 0.5, size: 2 + Math.random() * 4,
        })
      }
    }

    function addTrick(name: string, basePts: number) {
      const pts = Math.round(basePts * g.combo)
      g.score += pts
      popup(`${name} +${pts}`, true)
      g.combo = Math.min(8, g.combo + 1)
      g.comboT = 5
      g.shake = Math.max(g.shake, 0.25)
    }

    function wipe(reason: string) {
      phaseRef.current = 'over'
      sprayBurst(50)
      g.shake = 0.6
      const s = Math.floor(g.score)
      const rec = s > bestLocal
      if (rec) {
        bestLocal = s
        localStorage.setItem(BEST_KEY, String(s))
        setBest(s)
      }
      setIsRecord(rec)
      setFinalScore(s)
      setWipeReason(reason)
      setPhase('over')
    }

    function start() {
      g.h = 0.45; g.vh = 0; g.speed = 7; g.lead = 0.7; g.waveSpeed = 5
      g.score = 0; g.combo = 1; g.comboT = 0; g.t = 0; g.snapCd = 0; g.lastDir = 0
      g.air = 0; g.shake = 0; g.tubeT = 0
      g.barrelIn = 0; g.barrelWarn = 0; g.nextBarrel = 9
      g.popups = []; g.parts = []
      phaseRef.current = 'playing'
      setPhase('playing')
    }
    startFn.current = start

    function update(dt: number) {
      g.t += dt
      g.waveSpeed = 5 + Math.min(4.5, g.t * 0.045)
      const up = key.up || ptr.up
      const down = key.down || ptr.down

      if (g.air > 0) {
        g.air -= dt
        const p = 1 - g.air / g.airDur
        g.h = 1.12 + Math.sin(p * Math.PI) * 0.22 - p * 0.4
        if (g.air <= 0) {
          g.h = 0.72
          addTrick('AÉREO!', 260)
          sprayBurst(30)
        }
      } else {
        const dir = up ? 1 : down ? -1 : 0
        const target = dir === 1 ? 1.25 : dir === -1 ? -2.2 : -0.3
        g.vh += (target - g.vh) * Math.min(1, dt * 8)
        const prev = g.h
        g.h = clamp(g.h + g.vh * dt * 0.9, 0.04, 1.14)
        const dhdt = (g.h - prev) / dt
        if (dhdt < 0) g.speed += -dhdt * dt * 7 * (0.4 + prev)
        else g.speed -= dhdt * dt * 3.2
        if (g.h < 0.12) g.speed -= dt * 1.2
        if (g.lead < 0.45) g.speed += dt * 1.6
        g.speed += (5.5 - g.speed) * dt * 0.35
        g.speed = clamp(g.speed, 1.5, 15)

        g.snapCd -= dt
        if (g.h > 0.78 && down && g.lastDir === 1 && g.snapCd <= 0 && g.speed > 6) {
          g.snapCd = 0.9
          addTrick('SNAP!', 120)
          g.speed = Math.min(15, g.speed + 1.2)
          sprayBurst(26)
        }
        if (dir !== 0) g.lastDir = dir

        if (g.h >= 1.14) {
          if (g.speed >= 8.5 && g.barrelIn <= 0) {
            g.air = g.airDur
            sprayBurst(30)
          } else {
            g.h = 0.95
            g.vh = -0.6
            g.speed = Math.max(1.5, g.speed - 2)
            if (g.snapCd <= 0) {
              popup('quase passou da crista! 😅', false)
              g.snapCd = 0.9
            }
          }
        }
      }

      g.lead += (g.speed - g.waveSpeed) * dt * 0.075
      g.lead = Math.min(g.lead, 1.15)
      if (g.lead <= 0) { wipe('A espuma te engoliu 🌊'); return }

      g.score += g.speed * dt * 2

      if (g.combo > 1) {
        g.comboT -= dt
        if (g.comboT <= 0) g.combo = 1
      }

      if (g.barrelIn > 0) {
        g.barrelIn -= dt
        if (g.h > 0.8 && g.air <= 0) { wipe('Levou a lipada na cabeça dentro do tubo 🤕'); return }
        if (g.h >= 0.12 && g.h <= 0.52) {
          g.tubeT += dt
          g.score += dt * 90 * g.combo
        }
        if (g.barrelIn <= 0) {
          if (g.tubeT > 0.8) addTrick(`TUBO ${g.tubeT.toFixed(1)}s!`, Math.round(g.tubeT * 150))
          g.nextBarrel = 8 + Math.random() * 8
          g.tubeT = 0
        }
      } else if (g.barrelWarn > 0) {
        g.barrelWarn -= dt
        if (g.barrelWarn <= 0) {
          g.barrelIn = 4 + Math.random() * 2
          g.tubeT = 0
        }
      } else {
        g.nextBarrel -= dt
        if (g.nextBarrel <= 0) g.barrelWarn = 1.6
      }

      if (g.speed > 7.5 || Math.abs(g.vh) > 1) {
        const y = playerY()
        g.parts.push({
          x: px() - 16, y: y + 8,
          vx: -80 - g.speed * 12, vy: -40 - Math.random() * 90,
          life: 0.35 + Math.random() * 0.3, size: 1.5 + Math.random() * 3,
        })
      }
    }

    function updateFx(dt: number) {
      g.shake = Math.max(0, g.shake - dt)
      for (const p of g.parts) {
        p.x += p.vx * dt
        p.y += p.vy * dt
        p.vy += 380 * dt
        p.life -= dt
      }
      g.parts = g.parts.filter(p => p.life > 0)
      for (const p of g.popups) { p.t += dt; p.y -= 32 * dt }
      g.popups = g.popups.filter(p => p.t < 1.4)
    }

    function updateDemo(dt: number) {
      g.t += dt
      g.h = 0.45 + Math.sin(g.t * 1.1) * 0.28
      g.vh = Math.cos(g.t * 1.1) * 0.6
      g.lead = 0.7 + Math.sin(g.t * 0.5) * 0.08
      g.speed = 7
      if (Math.random() < 0.5) {
        g.parts.push({
          x: px() - 16, y: playerY() + 8,
          vx: -140, vy: -60 - Math.random() * 80,
          life: 0.4, size: 1.5 + Math.random() * 3,
        })
      }
    }

    function drawSurfer() {
      const x = px()
      const y = playerY()
      ctx!.save()
      ctx!.translate(x, y)
      let tilt = -0.12 + g.vh * -0.25
      if (g.air > 0) tilt += (1 - g.air / g.airDur) * Math.PI * 2
      ctx!.rotate(tilt)
      const grad = ctx!.createLinearGradient(-26, 0, 26, 0)
      grad.addColorStop(0, '#e879a0')
      grad.addColorStop(1, '#c2185b')
      ctx!.fillStyle = grad
      ctx!.beginPath()
      ctx!.ellipse(0, 9, 26, 5.5, 0, 0, Math.PI * 2)
      ctx!.fill()
      ctx!.strokeStyle = '#181828'
      ctx!.lineWidth = 4.5
      ctx!.lineCap = 'round'
      ctx!.lineJoin = 'round'
      ctx!.beginPath()
      ctx!.moveTo(-10, 6)
      ctx!.lineTo(-5, -6)
      ctx!.lineTo(3, -6)
      ctx!.lineTo(8, 6)
      ctx!.moveTo(-1, -6)
      ctx!.lineTo(2, -17)
      ctx!.moveTo(2, -14)
      ctx!.lineTo(-9, -19)
      ctx!.moveTo(2, -14)
      ctx!.lineTo(11, -9)
      ctx!.stroke()
      ctx!.fillStyle = '#e8b08a'
      ctx!.beginPath()
      ctx!.arc(3.5, -22, 4.5, 0, Math.PI * 2)
      ctx!.fill()
      ctx!.restore()
    }

    function draw() {
      const bY = bottomY()
      const x0 = px()
      const pY = playerY()
      const fx = foamX()

      ctx!.save()
      if (g.shake > 0) {
        ctx!.translate((Math.random() - 0.5) * g.shake * 14, (Math.random() - 0.5) * g.shake * 14)
      }

      const sky = ctx!.createLinearGradient(0, 0, 0, H * 0.55)
      sky.addColorStop(0, '#0f0f1a')
      sky.addColorStop(0.6, '#241234')
      sky.addColorStop(1, '#4a1d42')
      ctx!.fillStyle = sky
      ctx!.fillRect(0, 0, W, H * 0.55)

      for (let i = 0; i < 40; i++) {
        const sx = ((i * 97) % 100) / 100 * W
        const sy = ((i * 53) % 37) / 37 * H * 0.3
        ctx!.fillStyle = `rgba(255,255,255,${0.15 + 0.2 * Math.abs(Math.sin(g.t * 1.5 + i))})`
        ctx!.fillRect(sx, sy, 2, 2)
      }

      const sunX = W * 0.72, sunY = H * 0.15
      const glow = ctx!.createRadialGradient(sunX, sunY, 10, sunX, sunY, 180)
      glow.addColorStop(0, 'rgba(232,121,160,.5)')
      glow.addColorStop(1, 'rgba(232,121,160,0)')
      ctx!.fillStyle = glow
      ctx!.fillRect(sunX - 180, sunY - 180, 360, 360)
      const sun = ctx!.createLinearGradient(sunX, sunY - 50, sunX, sunY + 50)
      sun.addColorStop(0, '#f8b6c8')
      sun.addColorStop(1, '#c2185b')
      ctx!.fillStyle = sun
      ctx!.beginPath()
      ctx!.arc(sunX, sunY, 50, 0, Math.PI * 2)
      ctx!.fill()

      ctx!.fillStyle = '#141d38'
      ctx!.fillRect(0, H * 0.5, W, H * 0.5)

      ctx!.beginPath()
      ctx!.moveTo(0, crestY(0))
      for (let x = 0; x <= W; x += 16) ctx!.lineTo(x, crestY(x))
      ctx!.lineTo(W, H)
      ctx!.lineTo(0, H)
      ctx!.closePath()
      const water = ctx!.createLinearGradient(0, H * 0.26, 0, H)
      water.addColorStop(0, '#2b8aa8')
      water.addColorStop(0.45, '#155a7d')
      water.addColorStop(1, '#0a2440')
      ctx!.fillStyle = water
      ctx!.fill()

      ctx!.strokeStyle = 'rgba(255,255,255,.1)'
      ctx!.lineWidth = 2
      for (let k = 1; k <= 4; k++) {
        ctx!.beginPath()
        for (let x = 0; x <= W; x += 24) {
          const y = crestY(x) + k * (bY - crestY(x)) * 0.22 + Math.sin(x * 0.01 + g.t * 4 + k) * 4
          if (x === 0) ctx!.moveTo(x, y)
          else ctx!.lineTo(x, y)
        }
        ctx!.stroke()
      }

      ctx!.strokeStyle = 'rgba(255,255,255,.4)'
      ctx!.lineWidth = 3.5
      ctx!.beginPath()
      ctx!.moveTo(0, crestY(0))
      for (let x = 0; x <= W; x += 16) ctx!.lineTo(x, crestY(x))
      ctx!.stroke()

      if (fx > -100) {
        ctx!.beginPath()
        ctx!.moveTo(0, crestY(0))
        for (let x = 0; x <= fx; x += 16) ctx!.lineTo(x, crestY(x))
        ctx!.lineTo(fx, H)
        ctx!.lineTo(0, H)
        ctx!.closePath()
        ctx!.fillStyle = 'rgba(225,238,248,.22)'
        ctx!.fill()

        for (let y = crestY(Math.max(0, fx)); y < bY + 20; y += 20) {
          const wob = Math.sin(y * 0.08 + g.t * 6) * 9
          ctx!.fillStyle = `rgba(240,248,255,${0.55 - (y / H) * 0.25})`
          ctx!.beginPath()
          ctx!.arc(fx + wob, y, 11 + Math.sin(y + g.t * 8) * 4, 0, Math.PI * 2)
          ctx!.fill()
        }
        for (let x = Math.max(-20, fx - W * 0.5); x < fx; x += 28) {
          ctx!.fillStyle = 'rgba(240,248,255,.45)'
          ctx!.beginPath()
          ctx!.arc(x, crestY(x) + 6 + Math.sin(x * 0.2 + g.t * 5) * 4, 12, 0, Math.PI * 2)
          ctx!.fill()
        }
      }

      if (g.barrelWarn > 0 && phaseRef.current === 'playing') {
        ctx!.strokeStyle = `rgba(251,146,60,${0.4 + 0.4 * Math.sin(g.t * 12)})`
        ctx!.lineWidth = 6
        ctx!.beginPath()
        for (let x = x0 - 60; x <= x0 + 200; x += 16) ctx!.lineTo(x, crestY(x) - 4)
        ctx!.stroke()
      }

      if (g.barrelIn > 0 && phaseRef.current === 'playing') {
        const c0 = crestY(x0)
        const zoneTop = bY - 0.52 * (bY - c0)
        const zoneBot = bY - 0.12 * (bY - c0)
        ctx!.fillStyle = 'rgba(74,222,128,.08)'
        ctx!.fillRect(x0 - 130, zoneTop, 260, zoneBot - zoneTop)
        ctx!.setLineDash([8, 8])
        ctx!.strokeStyle = 'rgba(74,222,128,.35)'
        ctx!.lineWidth = 2
        ctx!.strokeRect(x0 - 130, zoneTop, 260, zoneBot - zoneTop)
        ctx!.setLineDash([])
        const sx = x0 - 60
        const sy = crestY(sx)
        const ex = x0 + 170
        const ey = sy + (bY - sy) * 0.42
        ctx!.lineCap = 'round'
        ctx!.strokeStyle = 'rgba(10,45,70,.55)'
        ctx!.lineWidth = 34
        ctx!.beginPath()
        ctx!.moveTo(sx - 90, sy + 6)
        ctx!.bezierCurveTo(sx + 30, sy - 75, ex - 40, sy - 60, ex, ey)
        ctx!.stroke()
        ctx!.strokeStyle = 'rgba(215,238,248,.92)'
        ctx!.lineWidth = 22
        ctx!.beginPath()
        ctx!.moveTo(sx - 90, sy + 2)
        ctx!.bezierCurveTo(sx + 30, sy - 80, ex - 40, sy - 65, ex, ey - 6)
        ctx!.stroke()
        for (let i = 0; i < 3; i++) {
          ctx!.fillStyle = 'rgba(240,248,255,.6)'
          ctx!.beginPath()
          ctx!.arc(ex - 6 + Math.sin(g.t * 9 + i * 2) * 8, ey + 8 + i * 16 + ((g.t * 140 + i * 40) % 50), 6, 0, Math.PI * 2)
          ctx!.fill()
        }
        const dark = ctx!.createRadialGradient(x0, pY, 70, x0, pY, W * 0.55)
        dark.addColorStop(0, 'rgba(2,10,24,0)')
        dark.addColorStop(1, 'rgba(2,10,24,.5)')
        ctx!.fillStyle = dark
        ctx!.fillRect(0, 0, W, H)
      }

      if (phaseRef.current !== 'over' && g.lead < 0.45) {
        const pocket = ctx!.createRadialGradient(x0, pY, 5, x0, pY, 90)
        pocket.addColorStop(0, 'rgba(74,222,128,.18)')
        pocket.addColorStop(1, 'rgba(74,222,128,0)')
        ctx!.fillStyle = pocket
        ctx!.fillRect(x0 - 90, pY - 90, 180, 180)
      }

      if (phaseRef.current !== 'over') drawSurfer()

      for (const p of g.parts) {
        ctx!.fillStyle = `rgba(240,248,255,${Math.min(0.85, p.life * 1.6)})`
        ctx!.beginPath()
        ctx!.arc(p.x, p.y, p.size, 0, Math.PI * 2)
        ctx!.fill()
      }

      for (const p of g.popups) {
        const a = 1 - p.t / 1.4
        ctx!.font = p.big ? '900 32px Inter, sans-serif' : '800 20px Inter, sans-serif'
        ctx!.textAlign = 'center'
        ctx!.lineWidth = 5
        ctx!.strokeStyle = `rgba(15,15,26,${a})`
        ctx!.strokeText(p.text, p.x, p.y)
        ctx!.fillStyle = p.big ? `rgba(248,182,200,${a})` : `rgba(255,255,255,${a})`
        ctx!.fillText(p.text, p.x, p.y)
      }

      if (phaseRef.current === 'playing') drawHud()
      ctx!.restore()
    }

    function drawHud() {
      ctx!.textAlign = 'left'
      ctx!.font = '700 12px Inter, sans-serif'
      ctx!.fillStyle = 'rgba(255,255,255,.5)'
      ctx!.fillText('PONTOS', 24, 38)
      ctx!.font = '900 32px Inter, sans-serif'
      ctx!.fillStyle = '#fff'
      ctx!.fillText(Math.floor(g.score).toLocaleString('pt-BR'), 24, 70)

      ctx!.textAlign = 'right'
      ctx!.font = '700 12px Inter, sans-serif'
      ctx!.fillStyle = 'rgba(255,255,255,.5)'
      ctx!.fillText('RECORDE', W - 24, 38)
      ctx!.font = '800 20px Inter, sans-serif'
      ctx!.fillStyle = 'rgba(248,182,200,.9)'
      ctx!.fillText(Math.max(bestLocal, Math.floor(g.score)).toLocaleString('pt-BR'), W - 24, 62)

      const bw = Math.min(220, W * 0.4)
      ctx!.textAlign = 'left'
      ctx!.font = '700 11px Inter, sans-serif'
      ctx!.fillStyle = 'rgba(255,255,255,.5)'
      ctx!.fillText('VELOCIDADE', 24, H - 52)
      ctx!.fillStyle = 'rgba(255,255,255,.12)'
      ctx!.beginPath()
      ctx!.roundRect(24, H - 42, bw, 12, 6)
      ctx!.fill()
      const sp = ctx!.createLinearGradient(24, 0, 24 + bw, 0)
      sp.addColorStop(0, '#e879a0')
      sp.addColorStop(1, '#c2185b')
      ctx!.fillStyle = sp
      ctx!.beginPath()
      ctx!.roundRect(24, H - 42, bw * clamp(g.speed / 15, 0.04, 1), 12, 6)
      ctx!.fill()

      ctx!.fillStyle = 'rgba(255,255,255,.5)'
      ctx!.fillText('ESPUMA', 24, H - 88)
      ctx!.fillStyle = 'rgba(255,255,255,.12)'
      ctx!.beginPath()
      ctx!.roundRect(24, H - 78, bw, 12, 6)
      ctx!.fill()
      ctx!.fillStyle = g.lead < 0.25 ? '#fb923c' : '#4ade80'
      ctx!.beginPath()
      ctx!.roundRect(24, H - 78, bw * clamp(g.lead / 1.15, 0.02, 1), 12, 6)
      ctx!.fill()

      if (g.combo > 1) {
        ctx!.textAlign = 'center'
        ctx!.font = '900 26px Inter, sans-serif'
        ctx!.fillStyle = '#f8b6c8'
        ctx!.fillText(`COMBO x${g.combo}`, W / 2, 46)
        ctx!.fillStyle = 'rgba(248,182,200,.3)'
        ctx!.fillRect(W / 2 - 60, 54, 120, 4)
        ctx!.fillStyle = '#e879a0'
        ctx!.fillRect(W / 2 - 60, 54, 120 * (g.comboT / 5), 4)
      }

      ctx!.textAlign = 'center'
      if (g.barrelWarn > 0) {
        ctx!.font = '900 30px Inter, sans-serif'
        ctx!.fillStyle = `rgba(251,146,60,${0.6 + 0.4 * Math.sin(g.t * 12)})`
        ctx!.fillText('VEM TUBO! DESCE! 🌊', W / 2, H * 0.22)
      } else if (g.barrelIn > 0 && g.h >= 0.12 && g.h <= 0.52) {
        ctx!.font = '900 24px Inter, sans-serif'
        ctx!.fillStyle = '#4ade80'
        ctx!.fillText(`DENTRO DO TUBO ${g.tubeT.toFixed(1)}s`, W / 2, H * 0.22)
      }
      if (g.lead < 0.25) {
        ctx!.font = '900 22px Inter, sans-serif'
        ctx!.fillStyle = `rgba(251,146,60,${0.6 + 0.4 * Math.sin(g.t * 14)})`
        ctx!.fillText('A ESPUMA TÁ CHEGANDO! ACELERA! ⚠️', W / 2, H * 0.3)
      }
    }

    function loop(now: number) {
      const dt = Math.min((now - last) / 1000, 0.033)
      last = now
      if (phaseRef.current === 'playing') update(dt)
      else updateDemo(dt)
      updateFx(dt)
      draw()
      raf = requestAnimationFrame(loop)
    }
    raf = requestAnimationFrame(loop)

    function onKeyDown(e: KeyboardEvent) {
      if (e.key === 'ArrowUp' || e.key === 'w' || e.key === 'W') { key.up = true; e.preventDefault() }
      if (e.key === 'ArrowDown' || e.key === 's' || e.key === 'S') { key.down = true; e.preventDefault() }
      if ((e.key === ' ' || e.key === 'Enter') && phaseRef.current !== 'playing') { start(); e.preventDefault() }
    }
    function onKeyUp(e: KeyboardEvent) {
      if (e.key === 'ArrowUp' || e.key === 'w' || e.key === 'W') key.up = false
      if (e.key === 'ArrowDown' || e.key === 's' || e.key === 'S') key.down = false
    }
    function setPtr(clientY: number) {
      const half = window.innerHeight / 2
      ptr.up = clientY < half
      ptr.down = !ptr.up
    }
    function onPointerDown(e: PointerEvent) {
      if (phaseRef.current !== 'playing') return
      ptr.active = true
      setPtr(e.clientY)
    }
    function onPointerMove(e: PointerEvent) {
      if (ptr.active) setPtr(e.clientY)
    }
    function onPointerUp() {
      ptr.active = false
      ptr.up = false
      ptr.down = false
    }
    window.addEventListener('keydown', onKeyDown)
    window.addEventListener('keyup', onKeyUp)
    canvas.addEventListener('pointerdown', onPointerDown)
    window.addEventListener('pointermove', onPointerMove)
    window.addEventListener('pointerup', onPointerUp)

    return () => {
      cancelAnimationFrame(raf)
      window.removeEventListener('resize', resize)
      window.removeEventListener('keydown', onKeyDown)
      window.removeEventListener('keyup', onKeyUp)
      canvas.removeEventListener('pointerdown', onPointerDown)
      window.removeEventListener('pointermove', onPointerMove)
      window.removeEventListener('pointerup', onPointerUp)
    }
  }, [])

  const overlayStyle: React.CSSProperties = {
    position: 'fixed', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center',
    background: 'rgba(15,15,26,.55)', backdropFilter: 'blur(4px)', zIndex: 10, padding: 24,
  }
  const cardStyle: React.CSSProperties = {
    background: 'rgba(15,15,26,.92)', border: '1px solid rgba(232,121,160,.25)', borderRadius: 20,
    padding: '40px 36px', maxWidth: 480, width: '100%', textAlign: 'center',
    boxShadow: '0 20px 60px rgba(0,0,0,.5)',
  }
  const btnStyle: React.CSSProperties = {
    background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', border: 'none', borderRadius: 12,
    padding: '14px 32px', fontSize: '1.05rem', fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit',
    boxShadow: '0 8px 30px rgba(232,121,160,.35)',
  }

  return (
    <div style={{ position: 'fixed', inset: 0, background: '#0f0f1a', overflow: 'hidden' }}>
      <canvas ref={canvasRef} style={{ display: 'block', touchAction: 'none' }} />

      {phase === 'menu' && (
        <div style={overlayStyle}>
          <div style={cardStyle}>
            <h1 style={{ fontSize: '2.4rem', fontWeight: 900, letterSpacing: -1.5, marginBottom: 8 }}>
              🏄 Honk <span style={{ background: 'linear-gradient(135deg,#e879a0,#f8b6c8)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>Surf</span>
            </h1>
            <p style={{ color: 'rgba(255,255,255,.55)', fontSize: '.95rem', marginBottom: 24 }}>
              Dropa, manda snap na crista e acerta o tubo — sem deixar a espuma te engolir.
            </p>
            <div style={{ textAlign: 'left', background: 'rgba(255,255,255,.04)', border: '1px solid rgba(255,255,255,.08)', borderRadius: 14, padding: '18px 20px', marginBottom: 28, fontSize: '.88rem', color: 'rgba(255,255,255,.7)', lineHeight: 2 }}>
              <div>⬆️⬇️ ou <b>W/S</b> — sobe e desce na onda <span style={{ color: 'rgba(255,255,255,.4)' }}>(no celular: toca em cima/embaixo)</span></div>
              <div>🏂 Desce a parede pra ganhar <b style={{ color: '#e879a0' }}>velocidade</b></div>
              <div>💥 Sobe até a crista e corta pra baixo = <b style={{ color: '#e879a0' }}>SNAP</b></div>
              <div>🚀 Crista com muita velocidade = <b style={{ color: '#e879a0' }}>AÉREO</b></div>
              <div>🌊 Quando vier o tubo, <b style={{ color: '#4ade80' }}>fica na parte de baixo</b></div>
            </div>
            <button onClick={() => startFn.current()} style={btnStyle}>Começar a surfar 🤙</button>
            {best > 0 && <p style={{ marginTop: 18, fontSize: '.85rem', color: 'rgba(248,182,200,.8)', fontWeight: 600 }}>Seu recorde: {best.toLocaleString('pt-BR')} pontos</p>}
            <p style={{ marginTop: 20 }}>
              <Link href="/" style={{ color: 'rgba(255,255,255,.4)', fontSize: '.85rem', textDecoration: 'none' }}>← Voltar pro Honk Ponk</Link>
            </p>
          </div>
        </div>
      )}

      {phase === 'over' && (
        <div style={overlayStyle}>
          <div style={cardStyle}>
            <div style={{ fontSize: '3rem', marginBottom: 8 }}>🌊💥</div>
            <h2 style={{ fontSize: '1.9rem', fontWeight: 900, letterSpacing: -1, marginBottom: 6 }}>Caldo!</h2>
            <p style={{ color: 'rgba(255,255,255,.55)', fontSize: '.95rem', marginBottom: 24 }}>{wipeReason}</p>
            <div style={{ background: 'rgba(255,255,255,.04)', border: '1px solid rgba(255,255,255,.08)', borderRadius: 14, padding: '20px', marginBottom: 24 }}>
              <div style={{ fontSize: '.8rem', fontWeight: 700, color: 'rgba(255,255,255,.5)', letterSpacing: 1 }}>PONTUAÇÃO</div>
              <div style={{ fontSize: '2.6rem', fontWeight: 900, background: 'linear-gradient(135deg,#e879a0,#f8b6c8)', WebkitBackgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>
                {finalScore.toLocaleString('pt-BR')}
              </div>
              {isRecord
                ? <div style={{ color: '#4ade80', fontWeight: 700, fontSize: '.9rem' }}>🏆 Novo recorde!</div>
                : <div style={{ color: 'rgba(255,255,255,.45)', fontSize: '.85rem' }}>Recorde: {best.toLocaleString('pt-BR')}</div>}
            </div>
            <button onClick={() => startFn.current()} style={btnStyle}>Surfar de novo 🏄</button>
            <p style={{ marginTop: 20 }}>
              <Link href="/" style={{ color: 'rgba(255,255,255,.4)', fontSize: '.85rem', textDecoration: 'none' }}>← Voltar pro Honk Ponk</Link>
            </p>
          </div>
        </div>
      )}
    </div>
  )
}
