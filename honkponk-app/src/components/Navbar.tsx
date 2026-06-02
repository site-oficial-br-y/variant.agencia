'use client'
import { useState, useEffect } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { createClient } from '@/lib/supabase/client'

interface NavbarProps {
  onOpenQuiz?: () => void
}

export function Navbar({ onOpenQuiz }: NavbarProps) {
  const [isLoggedIn, setIsLoggedIn] = useState(false)
  const [scrolled, setScrolled] = useState(false)
  const supabase = createClient()

  useEffect(() => {
    supabase.auth.getUser().then(({ data }) => setIsLoggedIn(!!data.user))
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_, session) => setIsLoggedIn(!!session))
    return () => subscription.unsubscribe()
  }, [supabase])

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 20)
    window.addEventListener('scroll', onScroll)
    return () => window.removeEventListener('scroll', onScroll)
  }, [])

  return (
    <nav style={{ position: 'fixed', top: 0, left: 0, right: 0, zIndex: 1000, padding: '14px 24px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: scrolled ? 'rgba(15,15,26,0.92)' : 'rgba(15,15,26,0.7)', backdropFilter: 'blur(20px)', borderBottom: scrolled ? '1px solid rgba(248,182,200,0.12)' : '1px solid transparent', transition: 'all .3s' }}>
      <Link href="/" style={{ display: 'flex', alignItems: 'center', gap: 10, textDecoration: 'none' }}>
        <Image src="/logo.png" alt="Honk Ponk" width={32} height={32} style={{ objectFit: 'contain', borderRadius: 6 }} />
        <span style={{ fontSize: '1.2rem', fontWeight: 800, color: '#fff', letterSpacing: '-.5px' }}>
          Honk <em style={{ color: '#e879a0', fontStyle: 'normal' }}>Ponk</em>
        </span>
      </Link>

      <div style={{ display: 'flex', alignItems: 'center', gap: 32 }}>
        <div style={{ display: 'flex', gap: 28 }}>
          {[['#como-funciona','Como funciona'],['#recursos','Recursos'],['#precos','Preços']].map(([href,label]) => (
            <a key={href} href={href} style={{ fontSize: '.875rem', fontWeight: 500, color: 'rgba(255,255,255,.6)', textDecoration: 'none', transition: 'color .2s' }}
              onMouseEnter={e => (e.target as HTMLElement).style.color='#fff'}
              onMouseLeave={e => (e.target as HTMLElement).style.color='rgba(255,255,255,.6)'}
            >{label}</a>
          ))}
          <button onClick={onOpenQuiz} style={{ fontSize: '.875rem', fontWeight: 500, color: 'rgba(255,255,255,.6)', background: 'none', border: 'none', cursor: 'pointer', padding: 0, fontFamily: 'inherit', transition: 'color .2s' }}
            onMouseEnter={e => (e.target as HTMLElement).style.color='#fff'}
            onMouseLeave={e => (e.target as HTMLElement).style.color='rgba(255,255,255,.6)'}
          >Buscar leads</button>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
          <a href="https://www.instagram.com/honkponk.oficial" target="_blank" rel="noopener" style={{ color: 'rgba(255,255,255,.6)', textDecoration: 'none', fontSize: '1.2rem' }}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z"/></svg>
          </a>
          <a href="https://www.tiktok.com/@honk.ponk1" target="_blank" rel="noopener" style={{ color: 'rgba(255,255,255,.6)', textDecoration: 'none', fontSize: '1.2rem' }}>
            <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M19.59 6.69a4.83 4.83 0 01-3.77-4.25V2h-3.45v13.67a2.89 2.89 0 01-2.88 2.5 2.89 2.89 0 01-2.89-2.89 2.89 2.89 0 012.89-2.89c.28 0 .54.04.79.1V9.01a6.33 6.33 0 00-.79-.05 6.34 6.34 0 00-6.34 6.34 6.34 6.34 0 006.34 6.34 6.34 6.34 0 006.33-6.34V8.69a8.18 8.18 0 004.78 1.52V6.76a4.85 4.85 0 01-1.01-.07z"/></svg>
          </a>
          {isLoggedIn ? (
            <Link href="/dashboard" style={{ background: 'rgba(248,182,200,.1)', color: '#f8b6c8', border: '1px solid rgba(248,182,200,.25)', borderRadius: 10, padding: '8px 18px', fontSize: '.875rem', fontWeight: 600, textDecoration: 'none' }}>
              Minha Conta
            </Link>
          ) : (
            <button onClick={onOpenQuiz} style={{ background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', border: 'none', borderRadius: 10, padding: '9px 20px', fontSize: '.875rem', fontWeight: 700, cursor: 'pointer', boxShadow: '0 4px 15px rgba(232,121,160,.35)', fontFamily: 'inherit' }}>
              Começar grátis →
            </button>
          )}
        </div>
      </div>
    </nav>
  )
}
