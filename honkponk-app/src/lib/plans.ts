export type Plan = 'free' | 'freelancer' | 'agency' | 'enterprise'

export interface PlanConfig {
  name: string
  description: string
  price: number
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
    searchesPerDay: 10,
    maxResults: null,
    allContacts: true,
    exportExcel: false,
    maxUsers: 1,
    dedicatedSupport: false,
    features: ['10 buscas por dia','Resultados ilimitados','Todos os leads (com ou sem contato)','WhatsApp + Instagram + Telefone + Site','Filtro inteligente por serviço'],
  },
  agency: {
    name: 'Agência',
    description: 'Para agências e equipes',
    price: 5990,
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
