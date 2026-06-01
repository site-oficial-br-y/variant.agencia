import Link from 'next/link'

export default function PendingPage() {
  return (
    <div style={{ minHeight: '100vh', background: '#0f0f1a', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 24 }}>
      <div style={{ textAlign: 'center', maxWidth: 480 }}>
        <div style={{ fontSize: '4rem', marginBottom: 24 }}>⏳</div>
        <h1 style={{ fontSize: '2rem', fontWeight: 900, letterSpacing: -1, marginBottom: 12 }}>Pagamento pendente</h1>
        <p style={{ color: 'rgba(255,255,255,.6)', lineHeight: 1.7, marginBottom: 36 }}>Seu pagamento está sendo processado. Assim que for confirmado, seu plano será ativado automaticamente.</p>
        <Link href="/dashboard" style={{ display: 'inline-block', background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', borderRadius: 12, padding: '14px 28px', fontSize: '1rem', fontWeight: 700, textDecoration: 'none' }}>Voltar ao dashboard →</Link>
      </div>
    </div>
  )
}
