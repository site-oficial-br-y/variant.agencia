'use client'
import { Suspense, useCallback, useEffect, useRef, useState } from 'react'
import { useSearchParams } from 'next/navigation'
import Link from 'next/link'
import { createClient } from '@/lib/supabase/client'
import { PLANS } from '@/lib/plans'
import type { Plan } from '@/lib/plans'

/* A tela antes afirmava "plano ativado" no instante em que o Mercado Pago
   devolvia a pessoa pro site. Só que quem libera o plano é o webhook, que chega
   segundos ou minutos depois. Quem clicava em buscar na hora ainda era tratado
   como grátis e levava o teto de 5 resultados, o que já gerou reclamação de
   cliente. Agora a tela confirma no banco antes de liberar. */

const INTERVALO_MS = 2500
const TENTATIVAS = 32 // ~80 segundos

type Estado = 'confirmando' | 'pronto' | 'demorou' | 'sem-sessao'

function SuccessContent() {
  const params = useSearchParams()
  const plano = params.get('plan') as Plan | null
  const coinsComprados = Number(params.get('coins') || 0)
  const ehCoins = coinsComprados > 0

  const [estado, setEstado] = useState<Estado>('confirmando')
  const [saldo, setSaldo] = useState<number | null>(null)
  const saldoInicial = useRef<number | null>(null)
  const tentativas = useRef(0)

  const conferir = useCallback(async (): Promise<boolean> => {
    const supabase = createClient()
    const { data: { user } } = await supabase.auth.getUser()
    if (!user) {
      setEstado('sem-sessao')
      return true
    }
    const { data } = await supabase
      .from('users_profiles')
      .select('plan, plan_expires_at, honk_coins')
      .eq('id', user.id)
      .single()
    if (!data) return false

    const perfil = data as { plan?: string; plan_expires_at?: string | null; honk_coins?: number }

    if (ehCoins) {
      const atual = perfil.honk_coins ?? 0
      setSaldo(atual)
      if (saldoInicial.current === null) {
        saldoInicial.current = atual
        return false
      }
      if (atual > saldoInicial.current) {
        setEstado('pronto')
        return true
      }
      return false
    }

    const valido = perfil.plan_expires_at
      ? new Date(perfil.plan_expires_at).getTime() > Date.now()
      : false
    if (perfil.plan && perfil.plan !== 'free' && valido && (!plano || perfil.plan === plano)) {
      setEstado('pronto')
      return true
    }
    return false
  }, [ehCoins, plano])

  useEffect(() => {
    let vivo = true
    let timer: ReturnType<typeof setTimeout>

    const rodar = async () => {
      if (!vivo) return
      let terminou = false
      try {
        terminou = await conferir()
      } catch {
        // Falha de rede não pode travar a pessoa: segue tentando.
      }
      if (!vivo || terminou) return
      tentativas.current += 1
      if (tentativas.current >= TENTATIVAS) {
        setEstado('demorou')
        return
      }
      timer = setTimeout(rodar, INTERVALO_MS)
    }

    rodar()
    return () => { vivo = false; clearTimeout(timer) }
  }, [conferir])

  const tentarDeNovo = () => {
    tentativas.current = 0
    setEstado('confirmando')
    conferir().catch(() => {})
  }

  const config = plano ? PLANS[plano] : null
  const caixa: React.CSSProperties = {
    minHeight: '100vh', background: '#0f0f1a', color: '#fff',
    display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24,
    fontFamily: 'Inter, -apple-system, sans-serif',
  }
  const botao: React.CSSProperties = {
    display: 'inline-block', background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff',
    borderRadius: 12, padding: '14px 28px', fontSize: '1rem', fontWeight: 700, textDecoration: 'none',
    border: 0, cursor: 'pointer',
  }
  const botaoSecundario: React.CSSProperties = {
    display: 'inline-block', background: 'rgba(255,255,255,.08)', color: 'rgba(255,255,255,.7)',
    border: '1px solid rgba(255,255,255,.12)', borderRadius: 12, padding: '14px 28px',
    fontSize: '1rem', fontWeight: 600, textDecoration: 'none', cursor: 'pointer',
  }

  if (estado === 'confirmando') {
    return (
      <div style={caixa}>
        <div style={{ textAlign: 'center', maxWidth: 480 }}>
          <style>{'@keyframes gira{to{transform:rotate(360deg)}}'}</style>
          <div style={{
            width: 46, height: 46, margin: '0 auto 26px', borderRadius: '50%',
            border: '3px solid rgba(248,182,200,.2)', borderTopColor: '#e879a0',
            animation: 'gira 900ms linear infinite',
          }} />
          <h1 style={{ fontSize: '1.6rem', fontWeight: 900, letterSpacing: -.6, marginBottom: 12 }}>
            Pagamento aprovado. Confirmando a liberação.
          </h1>
          <p style={{ color: 'rgba(255,255,255,.6)', lineHeight: 1.7 }}>
            Isso costuma levar poucos segundos. Fica nesta tela que ela avisa sozinha quando estiver tudo pronto.
          </p>
        </div>
      </div>
    )
  }

  if (estado === 'demorou' || estado === 'sem-sessao') {
    const semSessao = estado === 'sem-sessao'
    return (
      <div style={caixa}>
        <div style={{ textAlign: 'center', maxWidth: 480 }}>
          <h1 style={{ fontSize: '1.6rem', fontWeight: 900, letterSpacing: -.6, marginBottom: 12 }}>
            Pagamento aprovado.
          </h1>
          <p style={{ color: 'rgba(255,255,255,.6)', lineHeight: 1.7, marginBottom: 28 }}>
            {semSessao
              ? 'Entre na sua conta para ver a liberação. Se ela ainda não tiver aparecido, aguarde alguns minutos e recarregue.'
              : 'A liberação está demorando mais que o normal. Ela costuma cair sozinha em alguns minutos. Se não cair, escreve para honkponkoficial@gmail.com que eu resolvo no mesmo dia.'}
          </p>
          <div style={{ display: 'flex', gap: 12, justifyContent: 'center', flexWrap: 'wrap' }}>
            {!semSessao && <button onClick={tentarDeNovo} style={botao}>Verificar de novo</button>}
            <Link href={semSessao ? '/login' : '/dashboard'} style={semSessao ? botao : botaoSecundario}>
              {semSessao ? 'Entrar na conta' : 'Ir para o dashboard'}
            </Link>
          </div>
        </div>
      </div>
    )
  }

  return (
    <div style={caixa}>
      <div style={{ textAlign: 'center', maxWidth: 480 }}>
        <div style={{ fontSize: '4rem', marginBottom: 24 }}>🎉</div>
        <h1 style={{ fontSize: '2rem', fontWeight: 900, letterSpacing: -1, marginBottom: 12 }}>
          {ehCoins ? 'Coins creditados!' : 'Plano ativado!'}
        </h1>
        <p style={{ color: 'rgba(255,255,255,.6)', lineHeight: 1.7, marginBottom: 8 }}>
          {ehCoins ? (
            <>Seu saldo agora é de <strong style={{ color: '#f8b6c8' }}>{saldo} Honk Coins</strong>.</>
          ) : (
            <>Seu plano <strong style={{ color: '#f8b6c8' }}>{config?.name || plano}</strong> já está valendo.</>
          )}
        </p>
        <p style={{ color: 'rgba(255,255,255,.4)', fontSize: '.9rem', marginBottom: 36 }}>
          Pode buscar à vontade.
        </p>
        <div style={{ display: 'flex', gap: 12, justifyContent: 'center', flexWrap: 'wrap' }}>
          <Link href="/dashboard" style={botao}>Ir para o dashboard →</Link>
          <Link href="/" style={botaoSecundario}>Buscar leads</Link>
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
