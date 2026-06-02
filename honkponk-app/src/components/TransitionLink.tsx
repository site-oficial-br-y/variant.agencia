'use client'
import { useRouter } from 'next/navigation'
import { useRef } from 'react'

interface TransitionLinkProps {
  href: string
  style?: React.CSSProperties
  children: React.ReactNode
}

export function TransitionLink({ href, style, children }: TransitionLinkProps) {
  const router = useRouter()
  const overlayRef = useRef<HTMLDivElement | null>(null)

  function handleClick(e: React.MouseEvent) {
    e.preventDefault()

    // Create overlay
    const overlay = document.createElement('div')
    overlay.style.cssText = `
      position:fixed;inset:0;z-index:9999;
      background:#0f0f1a;
      opacity:0;
      transition:opacity .35s ease;
      pointer-events:none;
    `
    document.body.appendChild(overlay)
    overlayRef.current = overlay

    // Fade in overlay then navigate
    requestAnimationFrame(() => {
      overlay.style.opacity = '1'
    })
    setTimeout(() => {
      router.push(href)
    }, 360)
  }

  return (
    <a href={href} onClick={handleClick} style={style}>
      {children}
    </a>
  )
}
