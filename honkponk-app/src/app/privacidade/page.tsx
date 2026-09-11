import Link from 'next/link'
import Image from 'next/image'

export const metadata = {
  title: 'Política de Privacidade — Honk Ponk',
  description: 'Como a Honk Ponk coleta, usa e protege seus dados pessoais.',
}

export default function PrivacidadePage() {
  return (
    <main style={{ minHeight: '100vh', background: '#0f0f1a', color: '#fff', fontFamily: 'Inter, -apple-system, sans-serif' }}>
      <nav style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '20px 24px', borderBottom: '1px solid rgba(248,182,200,.12)' }}>
        <Link href="/" style={{ display: 'inline-flex', alignItems: 'center', gap: 10, textDecoration: 'none' }}>
          <Image src="/logo.png" alt="Honk Ponk" width={32} height={32} style={{ objectFit: 'contain', borderRadius: 8 }} />
          <span style={{ fontSize: '1.2rem', fontWeight: 800, color: '#fff' }}>Honk <em style={{ color: '#e879a0', fontStyle: 'normal' }}>Ponk</em></span>
        </Link>
        <Link href="/" style={{ color: 'rgba(255,255,255,.6)', textDecoration: 'none', fontSize: '.875rem' }}>← Voltar</Link>
      </nav>
      <div style={{ maxWidth: 760, margin: '0 auto', padding: '60px 24px' }}>
        <h1 style={{ fontSize: '2.5rem', fontWeight: 900, letterSpacing: -1.5, marginBottom: 8 }}>Política de Privacidade</h1>
        <p style={{ color: 'rgba(255,255,255,.4)', marginBottom: 48, fontSize: '.9rem' }}>Última atualização: Setembro de 2026</p>
        {[
          { title: '1. Quem somos', content: 'A Honk Ponk é uma plataforma de prospecção B2B operada de Santos, São Paulo. Para qualquer assunto relacionado a dados pessoais, incluindo pedidos de acesso ou exclusão, o contato é honkponkoficial@gmail.com.' },
          { title: '2. Quais dados coletamos', content: 'Apenas o necessário para o serviço funcionar: e-mail de cadastro; senha, guardada em formato embaralhado (hash), que não permite recuperar a senha original nem por nós; plano contratado e sua validade; saldo de Honk Coins; e o histórico das buscas realizadas, que registra o tipo de serviço, a região e a data. Também registramos o endereço de IP das requisições de forma temporária, apenas para conter abuso e excesso de uso.' },
          { title: '3. O que não coletamos', content: 'Não pedimos nem armazenamos número de cartão, CPF, endereço residencial ou documentos. Nenhuma dessas informações passa pelos nossos servidores.' },
          { title: '4. Por que coletamos', content: 'E-mail e senha para permitir o acesso à sua conta. Plano e validade para liberar o que você contratou. Histórico de buscas para exibir suas buscas recentes e acompanhar o uso da plataforma. IP para segurança e contenção de abuso. A base legal é a execução do contrato entre você e a Honk Ponk, prevista no artigo 7º, inciso V da LGPD, e o legítimo interesse em manter o serviço seguro.' },
          { title: '5. Com quem compartilhamos', content: 'Não vendemos, alugamos nem cedemos seus dados. Utilizamos fornecedores que tratam dados em nosso nome, cada um limitado ao necessário: Supabase (banco de dados e autenticação), Vercel (hospedagem do site), Mercado Pago (processamento dos pagamentos), Google (dados públicos de empresas e estatísticas de uso do site) e Resend (envio do e-mail de redefinição de senha).' },
          { title: '6. Pagamentos', content: 'Todo o pagamento acontece dentro do ambiente do Mercado Pago. Recebemos de volta apenas a confirmação de que o pagamento foi aprovado e qual plano foi contratado. Dados financeiros ficam sujeitos à política de privacidade do Mercado Pago.' },
          { title: '7. Cookies e medição de uso', content: 'Usamos cookie de sessão para manter você conectado após o login, e o Google Analytics para entender de forma agregada como as pessoas chegam e navegam pelo site. O Analytics não recebe seu e-mail, sua senha nem o conteúdo das suas buscas. Você pode bloquear cookies nas configurações do navegador, mas nesse caso o login deixa de funcionar.' },
          { title: '8. Armazenamento fora do Brasil', content: 'Os servidores dos nossos fornecedores podem estar localizados fora do país. A LGPD permite a transferência internacional desde que o mesmo nível de proteção seja mantido, e os fornecedores escolhidos atendem a esse requisito.' },
          { title: '9. Por quanto tempo guardamos', content: 'Enquanto a sua conta existir. Ao excluir a conta, os dados pessoais e o histórico de buscas são removidos. Registros relacionados a pagamentos podem ser mantidos pelo prazo exigido pela legislação fiscal e civil, mesmo após a exclusão.' },
          { title: '10. Seus direitos', content: 'Pela LGPD você pode confirmar a existência de tratamento, acessar, corrigir, portar e excluir seus dados, além de revogar o consentimento. A exclusão pode ser feita por você mesmo, a qualquer momento, pelo botão de excluir conta dentro do painel: ela é imediata, permanente e apaga também o seu histórico de buscas. Pedidos enviados por e-mail também são atendidos.' },
          { title: '11. Segurança', content: 'As senhas são armazenadas em formato embaralhado e nunca ficam visíveis para nós. O banco de dados usa controle de acesso por linha, de modo que cada usuário só consegue ler os próprios dados. Nenhum sistema é totalmente imune a falhas, mas tratamos qualquer incidente com seriedade e comunicamos as pessoas afetadas e a autoridade competente quando for o caso.' },
          { title: '12. Menores de idade', content: 'O serviço é destinado a maiores de 18 anos ou a menores autorizados e assistidos pelos responsáveis legais. Não coletamos dados de crianças de forma consciente.' },
          { title: '13. Alterações nesta Política', content: 'Esta Política pode ser atualizada conforme a plataforma evolui. Mudanças relevantes serão comunicadas na própria plataforma ou por e-mail, e a data de atualização no topo desta página é sempre revisada.' },
          { title: '14. Contato', content: 'Dúvidas sobre esta Política ou sobre o tratamento dos seus dados: honkponkoficial@gmail.com.' },
        ].map(s => (
          <div key={s.title} style={{ marginBottom: 36 }}>
            <h2 style={{ fontSize: '1.1rem', fontWeight: 800, color: '#f8b6c8', marginBottom: 10 }}>{s.title}</h2>
            <p style={{ fontSize: '.95rem', color: 'rgba(255,255,255,.65)', lineHeight: 1.8 }}>{s.content}</p>
          </div>
        ))}
        <div style={{ marginTop: 60, textAlign: 'center' }}>
          <Link href="/" style={{ display: 'inline-block', background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', borderRadius: 12, padding: '12px 24px', fontSize: '.9rem', fontWeight: 700, textDecoration: 'none' }}>
            Voltar para o início
          </Link>
        </div>
      </div>
    </main>
  )
}
