'use client'
import { useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

export default function LoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [resetSent, setResetSent] = useState(false)
  const [mode, setMode] = useState<'login' | 'reset'>('login')
  const router = useRouter()
  const supabase = createClient()

  async function handleLogin(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setLoading(true)
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) {
      setError('E-mail ou senha incorretos.')
    } else {
      router.push('/dashboard')
    }
    setLoading(false)
  }

  async function handleReset(e: React.FormEvent) {
    e.preventDefault()
    setError('')
    setLoading(true)
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/auth/callback`,
    })
    if (error) {
      setError('Erro ao enviar e-mail. Tente novamente.')
    } else {
      setResetSent(true)
    }
    setLoading(false)
  }

  return (
    <div style={{ minHeight: '100vh', background: '#0f0f1a', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <div style={{ width: '100%', maxWidth: 420 }}>
        <div style={{ textAlign: 'center', marginBottom: 36 }}>
          <Link href="/" style={{ display: 'inline-flex', alignItems: 'center', gap: 10, textDecoration: 'none', marginBottom: 24 }}>
            <Image src="https://site-oficial-br-y.github.io/Honkponk/logo.png" alt="Honk Ponk" width={40} height={40} style={{ objectFit: 'contain', borderRadius: 8 }} />
            <span style={{ fontSize: '1.4rem', fontWeight: 800, color: '#fff' }}>Honk <em style={{ color: '#e879a0', fontStyle: 'normal' }}>Ponk</em></span>
          </Link>
          <h1 style={{ fontSize: '1.8rem', fontWeight: 800, letterSpacing: -1, marginBottom: 8 }}>
            {mode === 'login' ? 'Entrar na conta' : 'Redefinir senha'}
          </h1>
        </div>

        <div style={{ background: '#16162a', border: '1px solid rgba(248,182,200,0.18)', borderRadius: 20, padding: 32 }}>
          {resetSent ? (
            <div style={{ textAlign: 'center', color: '#4ade80' }}>E-mail enviado! Verifique sua caixa de entrada.</div>
          ) : (
            <form onSubmit={mode === 'login' ? handleLogin : handleReset} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              <input type="email" value={email} onChange={e => setEmail(e.target.value)} placeholder="seu@email.com" required
                style={{ background: 'rgba(255,255,255,.06)', border: '1.5px solid rgba(255,255,255,.12)', borderRadius: 12, padding: '14px 18px', color: '#fff', fontSize: '.95rem', fontFamily: 'inherit', outline: 'none' }} />
              {mode === 'login' && (
                <input type="password" value={password} onChange={e => setPassword(e.target.value)} placeholder="Senha" required
                  style={{ background: 'rgba(255,255,255,.06)', border: '1.5px solid rgba(255,255,255,.12)', borderRadius: 12, padding: '14px 18px', color: '#fff', fontSize: '.95rem', fontFamily: 'inherit', outline: 'none' }} />
              )}
              {error && <p style={{ color: '#fb923c', fontSize: '.85rem' }}>{error}</p>}
              <button type="submit" disabled={loading}
                style={{ background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', border: 'none', borderRadius: 12, padding: '14px', fontSize: '1rem', fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit', boxShadow: '0 8px 30px rgba(232,121,160,.35)' }}>
                {loading ? 'Aguarde...' : mode === 'login' ? 'Entrar' : 'Enviar e-mail'}
              </button>
            </form>
          )}
          <div style={{ marginTop: 20, textAlign: 'center', fontSize: '.875rem', color: 'rgba(255,255,255,.4)' }}>
            {mode === 'login' ? (
              <>
                <button onClick={() => setMode('reset')} style={{ background: 'none', border: 'none', color: '#f8b6c8', cursor: 'pointer', fontFamily: 'inherit', fontSize: '.875rem' }}>Esqueci minha senha</button>
                <span style={{ margin: '0 10px' }}>·</span>
                <Link href="/signup" style={{ color: '#f8b6c8', textDecoration: 'none' }}>Criar conta</Link>
              </>
            ) : (
              <button onClick={() => setMode('login')} style={{ background: 'none', border: 'none', color: '#f8b6c8', cursor: 'pointer', fontFamily: 'inherit', fontSize: '.875rem' }}>← Voltar ao login</button>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
