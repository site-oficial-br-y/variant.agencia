'use client'
import { useState } from 'react'
import Link from 'next/link'
import Image from 'next/image'
import { useRouter } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

export default function SignupPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [terms, setTerms] = useState(false)
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const router = useRouter()
  const supabase = createClient()

  async function handleSignup(e: React.FormEvent) {
    e.preventDefault()
    if (!terms) { setError('Você precisa aceitar os Termos de Uso.'); return }
    setError('')
    setLoading(true)
    const { error } = await supabase.auth.signUp({
      email, password,
      options: { emailRedirectTo: `${window.location.origin}/auth/callback` },
    })
    if (error) {
      setError(error.message)
    } else {
      router.push('/dashboard')
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
          <h1 style={{ fontSize: '1.8rem', fontWeight: 800, letterSpacing: -1, marginBottom: 8 }}>Criar conta grátis</h1>
        </div>

        <div style={{ background: '#16162a', border: '1px solid rgba(248,182,200,0.18)', borderRadius: 20, padding: 32 }}>
          <form onSubmit={handleSignup} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            <input type="email" value={email} onChange={e => setEmail(e.target.value)} placeholder="seu@email.com" required
              style={{ background: 'rgba(255,255,255,.06)', border: '1.5px solid rgba(255,255,255,.12)', borderRadius: 12, padding: '14px 18px', color: '#fff', fontSize: '.95rem', fontFamily: 'inherit', outline: 'none' }} />
            <input type="password" value={password} onChange={e => setPassword(e.target.value)} placeholder="Crie uma senha (mín. 6 caracteres)" required minLength={6}
              style={{ background: 'rgba(255,255,255,.06)', border: '1.5px solid rgba(255,255,255,.12)', borderRadius: 12, padding: '14px 18px', color: '#fff', fontSize: '.95rem', fontFamily: 'inherit', outline: 'none' }} />
            <label style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: '.85rem', color: 'rgba(255,255,255,.6)', cursor: 'pointer' }}>
              <input type="checkbox" checked={terms} onChange={e => setTerms(e.target.checked)} style={{ accentColor: '#e879a0', width: 16, height: 16 }} />
              Li e aceito os <Link href="/termos" style={{ color: '#f8b6c8' }}>Termos de Uso</Link>
            </label>
            {error && <p style={{ color: '#fb923c', fontSize: '.85rem' }}>{error}</p>}
            <button type="submit" disabled={loading}
              style={{ background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', border: 'none', borderRadius: 12, padding: '14px', fontSize: '1rem', fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit', boxShadow: '0 8px 30px rgba(232,121,160,.35)' }}>
              {loading ? 'Criando conta...' : 'Criar conta grátis →'}
            </button>
          </form>
          <p style={{ marginTop: 20, textAlign: 'center', fontSize: '.875rem', color: 'rgba(255,255,255,.4)' }}>
            Já tem conta? <Link href="/login" style={{ color: '#f8b6c8', textDecoration: 'none' }}>Entrar</Link>
          </p>
        </div>
      </div>
    </div>
  )
}
