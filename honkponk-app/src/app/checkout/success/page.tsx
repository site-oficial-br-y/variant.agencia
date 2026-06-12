'use client'
import { Suspense } from 'react'
import { useSearchParams } from 'next/navigation'
import Link from 'next/link'
import { PLANS } from '@/lib/plans'
import type { Plan } from '@/lib/plans'

function SuccessContent() {
  const searchParams = useSearchParams()
  const plan = searchParams.get('plan') as Plan

  const planConfig = plan ? PLANS[plan] : null

  return (
    <div style={{ minHeight: '100vh', background: '#0f0f1a', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <div style={{ textAlign: 'center', maxWidth: 480 }}>
        <div style={{ fontSize: '4rem', marginBottom: 24 }}>🎉</div>
        <h1 style={{ fontSize: '2rem', fontWeight: 900, letterSpacing: -1, marginBottom: 12 }}>Pagamento aprovado!</h1>
        <p style={{ color: 'rgba(255,255,255,.6)', lineHeight: 1.7, marginBottom: 8 }}>
          Seu plano <strong style={{ color: '#f8b6c8' }}>{planConfig?.name || plan}</strong> foi ativado com sucesso.
        </p>
        <p style={{ color: 'rgba(255,255,255,.4)', fontSize: '.9rem', marginBottom: 36 }}>Bem-vindo à família Honk Ponk!</p>
        <div style={{ display: 'flex', gap: 12, justifyContent: 'center', flexWrap: 'wrap' }}>
          <Link href="/dashboard" style={{ display: 'inline-block', background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', borderRadius: 12, padding: '14px 28px', fontSize: '1rem', fontWeight: 700, textDecoration: 'none' }}>Ir para o dashboard →</Link>
          <Link href="/" style={{ display: 'inline-block', background: 'rgba(255,255,255,.08)', color: 'rgba(255,255,255,.7)', border: '1px solid rgba(255,255,255,.12)', borderRadius: 12, padding: '14px 28px', fontSize: '1rem', fontWeight: 600, textDecoration: 'none' }}>Buscar leads</Link>
        </div>
      </div>
    </div>
  )
}

export default function SuccessPage() {
  return (
    <Suspense fallback={<div style={{ minHeight: '100vh', background: '#0f0f1a' }} />}>
      <SuccessContent />
    </Suspense>
  )
}
