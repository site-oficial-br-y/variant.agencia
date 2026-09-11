import Link from 'next/link'
import Image from 'next/image'

export default function TermosPage() {
  return (
    <div style={{ minHeight: '100vh', background: '#0f0f1a', color: '#fff' }}>
      <nav style={{ padding: '16px 24px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', background: 'rgba(15,15,26,0.8)', backdropFilter: 'blur(20px)', borderBottom: '1px solid rgba(248,182,200,0.18)' }}>
        <Link href="/" style={{ display: 'flex', alignItems: 'center', gap: 10, textDecoration: 'none' }}>
          <Image src="/logo.png" alt="Honk Ponk" width={32} height={32} style={{ objectFit: 'contain', borderRadius: 6 }} />
          <span style={{ fontSize: '1.2rem', fontWeight: 800, color: '#fff' }}>Honk <em style={{ color: '#e879a0', fontStyle: 'normal' }}>Ponk</em></span>
        </Link>
        <Link href="/" style={{ color: 'rgba(255,255,255,.6)', textDecoration: 'none', fontSize: '.875rem' }}>← Voltar</Link>
      </nav>
      <div style={{ maxWidth: 760, margin: '0 auto', padding: '60px 24px' }}>
        <h1 style={{ fontSize: '2.5rem', fontWeight: 900, letterSpacing: -1.5, marginBottom: 8 }}>Termos de Uso</h1>
        <p style={{ color: 'rgba(255,255,255,.4)', marginBottom: 48, fontSize: '.9rem' }}>Última atualização: Setembro de 2026</p>
        {[
          { title: '1. Aceitação dos Termos', content: 'Ao criar uma conta ou utilizar a plataforma Honk Ponk, você concorda com estes Termos de Uso. Se não concordar com algum ponto, não utilize o serviço.' },
          { title: '2. Descrição do Serviço', content: 'A Honk Ponk é uma ferramenta de prospecção B2B. A partir de um tipo de serviço e uma região, ela retorna empresas que podem ter interesse nesse serviço, com os contatos que estiverem publicamente disponíveis. Os dados vêm da API do Google Places e são informações públicas de estabelecimentos. Não garantimos que estejam completos, atualizados ou corretos, porque não somos a origem deles.' },
          { title: '3. Cadastro e conta', content: 'Você é responsável pelas informações que cadastra e por manter sua senha em segurança. Cada conta é individual: compartilhar acesso fora do plano Empresa, que já prevê equipe, é motivo de suspensão. O serviço é destinado a maiores de 18 anos ou a menores autorizados e assistidos pelos responsáveis legais.' },
          { title: '4. Uso Aceitável', content: 'A plataforma deve ser usada apenas para prospecção comercial legítima. É proibido: enviar spam ou mensagens de assédio aos contatos obtidos; automatizar, raspar ou tentar contornar os limites de uso; revender ou redistribuir os dados; e usar os dados de forma que viole a LGPD ou qualquer outra lei. Podemos limitar ou suspender contas que apresentem uso abusivo, incluindo volume anormal de buscas.' },
          { title: '5. Planos e Pagamentos', content: 'Os planos pagos são contratados por período, com pagamento único processado pelo Mercado Pago. Não há cobrança recorrente nem renovação automática: terminado o período contratado, a conta volta ao plano Grátis e nada mais é cobrado. Para seguir em um plano pago, basta contratar de novo. Como não existe cobrança automática, não há assinatura a cancelar.' },
          { title: '6. Honk Coins', content: 'Os Honk Coins são créditos avulsos para fazer buscas além do limite do plano. Eles não têm prazo de validade, não são convertidos em dinheiro e não são transferidos entre contas. Créditos já consumidos em buscas realizadas não são restituídos.' },
          { title: '7. Plano Empresa e equipe', content: 'No plano Empresa, o titular pode convidar até quatro pessoas para usar a plataforma sob a mesma contratação. O titular é responsável pelo uso feito pelos convidados e pode remover o acesso deles a qualquer momento. Quando a contratação termina, o acesso da equipe termina junto.' },
          { title: '8. Arrependimento e reembolso', content: 'Nos termos do artigo 49 do Código de Defesa do Consumidor, você pode desistir da contratação em até 7 dias corridos a contar do pagamento, sem precisar justificar, e receber o valor de volta. Basta pedir pelo e-mail de contato. Passado esse prazo, pedidos de reembolso são analisados caso a caso.' },
          { title: '9. Disponibilidade', content: 'Trabalhamos para manter a plataforma no ar, mas ela depende de serviços de terceiros, como a API do Google, e pode ficar indisponível por manutenção ou falha fora do nosso controle. Interrupções curtas fazem parte da operação e não geram reembolso. Se a plataforma ficar indisponível por mais de 48 horas seguidas por falha nossa, você pode pedir o abatimento proporcional dos dias parados.' },
          { title: '10. Privacidade e dados', content: 'Coletamos o mínimo necessário para o serviço funcionar: e-mail, plano contratado e histórico das buscas realizadas. Dados de cartão e informações financeiras são tratados diretamente pelo Mercado Pago e nunca passam pelos nossos servidores nem ficam armazenados por nós. Não vendemos nem cedemos seus dados a terceiros.' },
          { title: '11. LGPD e exclusão de conta', content: 'Em conformidade com a Lei nº 13.709/2018, você pode acessar, corrigir, portar e excluir seus dados pessoais. A exclusão pode ser feita por você mesmo, a qualquer momento, pelo botão de excluir conta dentro do painel, e remove seus dados de forma permanente. Também aceitamos pedidos pelo e-mail de contato.' },
          { title: '12. Limitação de Responsabilidade', content: 'A Honk Ponk entrega dados públicos e ferramentas de organização, não resultados comerciais. Não nos responsabilizamos por decisões de negócio tomadas com base nas listas geradas, por dados imprecisos ou desatualizados vindos do Google Places, nem pelo conteúdo das abordagens que você faz aos contatos obtidos.' },
          { title: '13. Alterações nestes Termos', content: 'Estes Termos podem ser atualizados conforme a plataforma evolui. Mudanças relevantes serão comunicadas na própria plataforma ou por e-mail. Continuar usando o serviço após a atualização significa concordar com a nova versão.' },
          { title: '14. Lei aplicável e foro', content: 'Estes Termos são regidos pelas leis brasileiras. Fica eleito o foro da comarca de Santos, São Paulo, para resolver qualquer questão decorrente deles, sem prejuízo do direito do consumidor de acionar o foro do seu domicílio.' },
          { title: '15. Contato', content: 'Dúvidas, pedidos de reembolso e solicitações sobre dados pessoais: honkponkoficial@gmail.com.' },
        ].map(s => (
          <div key={s.title} style={{ marginBottom: 36 }}>
            <h2 style={{ fontSize: '1.1rem', fontWeight: 800, color: '#f8b6c8', marginBottom: 10 }}>{s.title}</h2>
            <p style={{ fontSize: '.95rem', color: 'rgba(255,255,255,.65)', lineHeight: 1.8 }}>{s.content}</p>
          </div>
        ))}
        <div style={{ marginTop: 60, textAlign: 'center' }}>
          <Link href="/" style={{ display: 'inline-block', background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', borderRadius: 12, padding: '12px 24px', fontSize: '.9rem', fontWeight: 700, textDecoration: 'none' }}>
            ← Voltar para o início
          </Link>
        </div>
      </div>
    </div>
  )
}
