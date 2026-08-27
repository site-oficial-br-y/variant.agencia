import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { getClientIp, isRateLimited } from '@/lib/rateLimit'

const GOOGLE_KEY = process.env.GOOGLE_PLACES_KEY || ''

// Cache de resultados pra economizar chamadas pagas ao Google Places
const supabaseCache = (process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.SUPABASE_SERVICE_ROLE_KEY)
  ? createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY)
  : null
const CACHE_TTL_MS = 7 * 24 * 60 * 60 * 1000 // 7 dias

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url)
  const action = searchParams.get('action')

  // Trava de emergência: essa rota chama o Google direto e pode ser acessada sem passar
  // pelo /api/search (que tem os limites por plano). A rede de segurança de verdade contra
  // custo é a cota diária configurada no Google Cloud Console — isso aqui só barra script óbvio.
  //
  // O teto precisa ser generoso porque UMA busca do usuário consome várias chamadas aqui:
  // "Todo o Brasil" dispara 10 (uma por cidade), busca por cidade em plano ilimitado usa 3
  // palavras-chave, e ainda tem geocode + raio ampliado — uma busca só chega a ~12 chamadas.
  // Operadora móvel no Brasil ainda usa CGNAT, então vários usuários dividem o mesmo IP.
  // Com o valor anterior (20/min) duas buscas "Todo o Brasil" seguidas já travavam o usuário,
  // e o front mostrava "nenhum resultado" em vez do erro — foi o que quebrou a busca em produção.
  const ip = getClientIp(req)
  if (isRateLimited(`places:${ip}`, 60 * 1000, 150)) {
    return NextResponse.json({ error: 'Muitas requisições. Tente novamente em instantes.' }, { status: 429 })
  }

  if (!GOOGLE_KEY) {
    return NextResponse.json({ error: 'API key not configured' }, { status: 500 })
  }

  if (action === 'geocode') {
    const address = searchParams.get('address') || ''
    const res = await fetch(
      `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(address)}&key=${GOOGLE_KEY}`
    )
    const data = await res.json()
    return NextResponse.json(data)
  }

  if (action === 'nearby') {
    const location = searchParams.get('location') || ''
    const radius = parseFloat(searchParams.get('radius') || '20000')
    const keyword = searchParams.get('keyword') || ''
    const [lat, lng] = location.split(',').map(Number)

    // 1) Tenta o cache antes de chamar o Google (economia de API)
    const cacheKey = `nearby:${keyword.toLowerCase()}:${lat.toFixed(2)}:${lng.toFixed(2)}:${Math.round(radius)}`
    if (supabaseCache) {
      try {
        const { data: cached } = await supabaseCache.from('places_cache').select('results, created_at').eq('cache_key', cacheKey).maybeSingle()
        if (cached && cached.created_at && (Date.now() - new Date(cached.created_at).getTime()) < CACHE_TTL_MS) {
          return NextResponse.json({ results: cached.results, status: 'OK', cached: true })
        }
      } catch { /* cache falhou, segue pro Google */ }
    }

    const body = {
      textQuery: keyword,
      locationBias: {
        circle: {
          center: { latitude: lat, longitude: lng },
          radius: Math.min(radius, 50000),
        },
      },
      languageCode: 'pt-BR',
      maxResultCount: 20,
    }

    const res = await fetch('https://places.googleapis.com/v1/places:searchText', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': GOOGLE_KEY,
        'X-Goog-FieldMask': 'places.id,places.displayName,places.formattedAddress,places.rating,places.userRatingCount,places.websiteUri,places.nationalPhoneNumber,places.currentOpeningHours',
      },
      body: JSON.stringify(body),
    })
    const data = await res.json()
    // Normalize to old format for compatibility
    const results = (data.places || []).map((p: any) => ({
      place_id: p.id,
      name: p.displayName?.text || '',
      vicinity: p.formattedAddress || '',
      rating: p.rating || 0,
      user_ratings_total: p.userRatingCount || 0,
      website: p.websiteUri || '',
      formatted_phone_number: p.nationalPhoneNumber || '',
      opening_hours: { open_now: p.currentOpeningHours?.openNow ?? null },
    }))

    // 2) Guarda no cache pra próximas buscas iguais não pagarem de novo
    if (supabaseCache && results.length && !data.error) {
      try {
        await supabaseCache.from('places_cache').upsert({ cache_key: cacheKey, results, created_at: new Date().toISOString() }, { onConflict: 'cache_key' })
      } catch { /* ignora erro de cache */ }
    }

    return NextResponse.json({ results, status: data.error ? 'ERROR' : 'OK', _raw_error: data.error })
  }

  if (action === 'details') {
    // New API includes details in nearby search, but support legacy calls
    const placeId = searchParams.get('place_id') || ''
    const res = await fetch(
      `https://places.googleapis.com/v1/places/${placeId}`,
      {
        headers: {
          'X-Goog-Api-Key': GOOGLE_KEY,
          'X-Goog-FieldMask': 'websiteUri,nationalPhoneNumber',
        },
      }
    )
    const data = await res.json()
    return NextResponse.json({ result: { website: data.websiteUri, formatted_phone_number: data.nationalPhoneNumber } })
  }

  if (action === 'test') {
    const keyPreview = GOOGLE_KEY ? `${GOOGLE_KEY.slice(0, 8)}...` : 'NOT SET'
    const geoRes = await fetch(`https://maps.googleapis.com/maps/api/geocode/json?address=Santos,Brasil&key=${GOOGLE_KEY}`)
    const geoData = await geoRes.json()
    let nearbyStatus = 'not tested'
    if (geoData.results?.[0]) {
      const { lat, lng } = geoData.results[0].geometry.location
      const nearbyRes = await fetch('https://places.googleapis.com/v1/places:searchText', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Goog-Api-Key': GOOGLE_KEY, 'X-Goog-FieldMask': 'places.id,places.displayName' },
        body: JSON.stringify({ textQuery: 'restaurantes', locationBias: { circle: { center: { latitude: lat, longitude: lng }, radius: 20000 } }, languageCode: 'pt-BR', maxResultCount: 5 }),
      })
      const nearbyData = await nearbyRes.json()
      nearbyStatus = nearbyData.error ? `ERROR: ${JSON.stringify(nearbyData.error)}` : `OK (${nearbyData.places?.length ?? 0} results): ${nearbyData.places?.map((p: any) => p.displayName?.text).join(', ')}`
    }
    return NextResponse.json({ keyPreview, geocodeStatus: geoData.status, nearbyStatus })
  }

  return NextResponse.json({ error: 'Invalid action' }, { status: 400 })
}
