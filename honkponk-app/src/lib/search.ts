export const SEGMENT_QUERIES: Record<string, string[]> = {
  restaurant: ['restaurantes', 'lanchonete', 'churrascaria', 'pizzaria', 'hamburgueria'],
  beauty: ['salões de beleza', 'barbearia', 'cabeleireiro', 'estética', 'manicure'],
  car_repair: ['oficinas mecânicas', 'auto center', 'funilaria', 'borracharia'],
  clinic: ['clínicas médicas', 'consultório médico', 'clínica odontológica', 'fisioterapia'],
  gym: ['academias', 'crossfit', 'musculação', 'pilates'],
  pharmacy: ['farmácias', 'drogaria'],
  hotel: ['hotéis', 'pousada', 'hostel'],
  supermarket: ['supermercados', 'mercado', 'mercearia', 'hortifruti'],
  bakery: ['padarias', 'confeitaria', 'panificadora', 'café'],
  bar: ['bares', 'boteco', 'pub', 'cervejaria'],
  dentist: ['dentistas', 'clínica odontológica', 'ortodontia'],
  school: ['escolas', 'colégio', 'creche', 'curso'],
  lawyer: ['escritórios de advocacia', 'advogado', 'escritório jurídico'],
  accounting: ['contabilidade', 'escritório contábil', 'contador'],
  clothing: ['lojas de roupa', 'boutique', 'moda', 'confecção'],
}

export const SEGMENT_NAMES: Record<string, string> = {
  restaurant: 'Restaurantes',
  beauty: 'Salões de Beleza',
  car_repair: 'Oficinas / Mecânicas',
  clinic: 'Clínicas & Consultórios',
  gym: 'Academias',
  pharmacy: 'Farmácias',
  hotel: 'Hotéis & Pousadas',
  supermarket: 'Supermercados',
  bakery: 'Padarias',
  bar: 'Bares',
  dentist: 'Dentistas',
  school: 'Escolas',
  lawyer: 'Escritórios de Advocacia',
  accounting: 'Contabilidades',
  clothing: 'Lojas de Roupa',
}

export interface ServiceMeta {
  name: string
  icon: string
  filterLabel: string
  filterFn: (place: { website?: string; reviews?: number }) => boolean
  showSiteTag: boolean
  waMsg: (name: string) => string
}

export const SERVICE_META: Record<string, ServiceMeta> = {
  sites: {
    name: 'Criação de Sites',
    icon: '🌐',
    filterLabel: 'Somente empresas SEM site cadastrado',
    filterFn: (p) => !p.website,
    showSiteTag: false,
    waMsg: (name) => `Olá, ${name}! Vi que seu negócio ainda não tem um site. Posso criar um para você com ótimo custo-benefício e ajudar a atrair mais clientes online. Posso te mostrar um exemplo?`,
  },
  marketing: {
    name: 'Marketing Digital',
    icon: '📱',
    filterLabel: 'Presença online fraca (sem site ou com poucas avaliações)',
    filterFn: (p) => !p.website || (p.reviews ?? 0) < 30,
    showSiteTag: false,
    waMsg: (name) => `Olá, ${name}! Trabalho com marketing digital e percebi que seu negócio pode crescer muito mais online. Posso te mostrar como atrair mais clientes pela internet?`,
  },
  design: {
    name: 'Design Gráfico',
    icon: '🎨',
    filterLabel: 'Todos os negócios',
    filterFn: () => true,
    showSiteTag: true,
    waMsg: (name) => `Olá, ${name}! Sou designer gráfico e gostaria de propor uma identidade visual profissional para seu negócio. Posso te enviar alguns exemplos do meu trabalho?`,
  },
  contabilidade: {
    name: 'Contabilidade',
    icon: '📊',
    filterLabel: 'Empresas menores (até 50 avaliações)',
    filterFn: (p) => (p.reviews ?? 0) < 50,
    showSiteTag: true,
    waMsg: (name) => `Olá, ${name}! Sou contador e ofereço serviços de contabilidade para pequenas empresas com preço justo. Posso te apresentar minha proposta?`,
  },
  software: {
    name: 'Software / Sistemas',
    icon: '💻',
    filterLabel: 'Todos os negócios',
    filterFn: () => true,
    showSiteTag: true,
    waMsg: (name) => `Olá, ${name}! Desenvolvo sistemas de gestão para negócios como o seu — controle de estoque, vendas e agendamentos. Posso te mostrar como funciona?`,
  },
  foto: {
    name: 'Foto / Vídeo',
    icon: '📷',
    filterLabel: 'Todos os negócios',
    filterFn: () => true,
    showSiteTag: true,
    waMsg: (name) => `Olá, ${name}! Sou fotógrafo profissional e adoraria fazer um ensaio para o seu negócio. Fotos de qualidade fazem toda a diferença para atrair clientes. Posso te enviar meu portfólio?`,
  },
  rh: {
    name: 'RH / Recrutamento',
    icon: '👥',
    filterLabel: 'Todos os negócios',
    filterFn: () => true,
    showSiteTag: true,
    waMsg: (name) => `Olá, ${name}! Trabalho com recrutamento e seleção para pequenas e médias empresas. Posso ajudar seu negócio a encontrar os melhores profissionais. Podemos conversar?`,
  },
  outros: {
    name: 'Outro serviço',
    icon: '✨',
    filterLabel: 'Todos os resultados disponíveis',
    filterFn: () => true,
    showSiteTag: true,
    waMsg: (name) => `Olá, ${name}! Tenho uma proposta que pode ajudar muito seu negócio. Podemos conversar alguns minutos?`,
  },
}

export interface PlaceResult {
  name: string
  address: string
  phone: string
  website: string
  rating: number
  reviews: number
  isOpen: boolean | null
  instagram?: string
  idealMatch?: boolean
}

export function hasContactInfo(place: PlaceResult): boolean {
  return !!(place.phone || place.instagram || place.website)
}
