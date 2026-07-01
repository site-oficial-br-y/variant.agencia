'use client'
import Link from 'next/link'
import Image from 'next/image'

export default function ConfirmarPage() {
  return (
    <div style={{ minHeight: '100vh', background: '#0f0f1a', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <div style={{ width: '100%', maxWidth: 440, textAlign: 'center' }}>
        <Link href="/" style={{ display: 'inline-flex', alignItems: 'center', gap: 10, textDecoration: 'none', marginBottom: 32 }}>
          <Image src="/logo.png" alt="Honk Ponk" width={40} height={40} style={{ objectFit: 'contain', borderRadius: 8 }} />
          <span style={{ fontSize: '1.4rem', fontWeight: 800, color: '#fff' }}>Honk <em style={{ color: '#e879a0', fontStyle: 'normal' }}>Ponk</em></span>
        </Link>
        <div style={{ background: '#16162a', border: '1px solid rgba(248,182,200,0.18)', borderRadius: 20, padding: 40 }}>
          <div style={{ fontSize: '3rem', marginBottom: 16 }}>📧</div>
          <h1 style={{ fontSize: '1.5rem', fontWeight: 800, letterSpacing: -0.5, marginBottom: 12, color: '#fff' }}>Confirme seu e-mail</h1>
          <p style={{ color: 'rgba(255,255,255,.6)', fontSize: '.92rem', lineHeight: 1.7, marginBottom: 8 }}>
            Enviamos um link de confirmação para o seu e-mail. Clique nele para ativar sua conta e começar a usar o Honk Ponk.
          </p>
          <p style={{ color: 'rgba(255,255,255,.4)', fontSize: '.82rem', marginBottom: 28 }}>
            Não recebeu? Verifique a caixa de spam.
          </p>
          <Link href="/login" style={{ display: 'inline-block', background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', borderRadius: 12, padding: '13px 28px', fontSize: '.95rem', fontWeight: 700, textDecoration: 'none' }}>
            Ir para o login
          </Link>
        </div>
      </div>
    </div>
  )
}
