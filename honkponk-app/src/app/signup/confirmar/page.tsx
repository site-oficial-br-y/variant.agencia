'use client'
import { useSearchParams } from 'next/navigation'
import Link from 'next/link'
import Image from 'next/image'

export default function ConfirmarPage() {
  const params = useSearchParams()
  const email = params.get('email') || 'seu e-mail'

  return (
    <div style={{ minHeight: '100vh', background: '#0f0f1a', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <div style={{ width: '100%', maxWidth: 420, textAlign: 'center' }}>
        <Link href="/" style={{ display: 'inline-flex', alignItems: 'center', gap: 10, textDecoration: 'none', marginBottom: 40 }}>
          <Image src="https://site-oficial-br-y.github.io/Honkponk/logo.png" alt="Honk Ponk" width={36} height={36} style={{ objectFit: 'contain', borderRadius: 6 }} />
          <span style={{ fontSize: '1.3rem', fontWeight: 800, color: '#fff' }}>Honk <em style={{ color: '#e879a0', fontStyle: 'normal' }}>Ponk</em></span>
        </Link>
        <div style={{ fontSize: '3rem', marginBottom: 20 }}>📧</div>
        <h1 style={{ fontSize: '1.6rem', fontWeight: 800, letterSpacing: -1, marginBottom: 12 }}>Confirme seu e-mail</h1>
        <p style={{ color: 'rgba(255,255,255,.5)', lineHeight: 1.7, marginBottom: 8 }}>
          Enviamos um link de confirmação para:
        </p>
        <p style={{ color: '#f8b6c8', fontWeight: 700, marginBottom: 28, fontSize: '1rem' }}>{email}</p>
        <p style={{ color: 'rgba(255,255,255,.4)', fontSize: '.85rem', lineHeight: 1.7, marginBottom: 32 }}>
          Clique no link do e-mail para ativar sua conta. Não se esqueça de verificar a pasta de <strong style={{ color: 'rgba(255,255,255,.6)' }}>spam</strong>.
        </p>
        <Link href="/login" style={{ display: 'inline-block', background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', borderRadius: 12, padding: '13px 28px', fontSize: '.95rem', fontWeight: 700, textDecoration: 'none' }}>
          Já confirmei → Entrar
        </Link>
      </div>
    </div>
  )
}
