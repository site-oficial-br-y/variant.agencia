export type Plan = 'free' | 'freelancer' | 'agency' | 'enterprise'

export type BillingPeriod = 1 | 3 | 6 | 12

export interface PeriodPrice {
  months: BillingPeriod
  label: string
  price: number // em centavos
  badge?: string
}

export interface PlanConfig {
  name: string
  description: string
  price: number
  periods: PeriodPrice[]
  searchesPerDay: number | null
  maxResults: number | null
  allContacts: boolean
  exportExcel: boolean
  maxUsers: number
  dedicatedSupport: boolean
  features: string[]
}

export const PLANS: Record<Plan, PlanConfig> = {
  free: {
    name: 'Grátis',
    description: 'Para experimentar',
    price: 0,
    periods: [],
    searchesPerDay: 1,
    maxResults: 5,
    allContacts: false,
    exportExcel: false,
    maxUsers: 1,
    dedicatedSupport: false,
    features: ['1 busca por dia','Até 5 leads por busca','Apenas leads com contato disponível','WhatsApp + Instagram'],
  },
  freelancer: {
    name: 'Freelancer',
    description: 'Para profissionais autônomos',
    price: 1990,
    periods: [
      { months: 1,  label: '1 mês',   price:  1990 },
      { months: 3,  label: '3 meses', price:  4990, badge: '-17%' },
      { months: 6,  label: '6 meses', price:  8990, badge: '-25%' },
      { months: 12, label: '1 ano',   price: 15990, badge: '-33%' },
    ],
    searchesPerDay: 10,
    maxResults: null,
    allContacts: true,
    exportExcel: false,
    maxUsers: 1,
    dedicatedSupport: false,
    features: ['10 buscas por dia (cada busca traz dezenas de leads)','Resultados ilimitados por busca','Todos os leads (com ou sem contato)','WhatsApp + Instagram + Telefone + Site','Filtro inteligente por serviço'],
  },
  agency: {
    name: 'Agência',
    description: 'Para agências e equipes',
    price: 5990,
    periods: [
      { months: 1,  label: '1 mês',   price:  5990 },
      { months: 3,  label: '3 meses', price: 15990, badge: '-11%' },
      { months: 6,  label: '6 meses', price: 27990, badge: '-22%' },
      { months: 12, label: '1 ano',   price: 49990, badge: '-30%' },
    ],
    searchesPerDay: null,
    maxResults: null,
    allContacts: true,
    exportExcel: true,
    maxUsers: 1,
    dedicatedSupport: false,
    features: ['Buscas ilimitadas','Resultados ilimitados','Exportar leads para Excel','Todos os contatos disponíveis','Filtro inteligente por serviço','Acesso prioritário a novos recursos'],
  },
  enterprise: {
    name: 'Empresa',
    description: 'Para empresas com equipe',
    price: 9990,
    periods: [
      { months: 1,  label: '1 mês',   price:  9990 },
      { months: 3,  label: '3 meses', price: 26990, badge: '-10%' },
      { months: 6,  label: '6 meses', price: 47990, badge: '-20%' },
      { months: 12, label: '1 ano',   price: 83990, badge: '-30%' },
    ],
    searchesPerDay: null,
    maxResults: null,
    allContacts: true,
    exportExcel: true,
    maxUsers: 5,
    dedicatedSupport: true,
    features: ['Tudo do plano Agência','Até 5 usuários na equipe','Suporte dedicado por e-mail','Relatórios de uso da equipe'],
  },
}

export function formatPrice(cents: number): string {
  return `R$${(cents / 100).toFixed(2).replace('.', ',')}`
}

export function canSearch(plan: Plan, searchesToday: number): boolean {
  const config = PLANS[plan]
  if (config.searchesPerDay === null) return true
  return searchesToday < config.searchesPerDay
}

export function getRemainingSearches(plan: Plan, searchesToday: number): number | null {
  const config = PLANS[plan]
  if (config.searchesPerDay === null) return null
  return Math.max(0, config.searchesPerDay - searchesToday)
}
