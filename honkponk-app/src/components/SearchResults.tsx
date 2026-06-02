'use client'
import { useState, useCallback } from 'react'
import { SEGMENT_QUERIES, SERVICE_META } from '@/lib/search'
import type { PlaceResult } from '@/lib/search'
import { PLANS } from '@/lib/plans'
import type { Plan } from '@/lib/plans'

interface SearchParams { service: string; city: string; segment: string; allBrazil: boolean }

async function geocodeCity(city: string): Promise<{ lat: number; lng: number }> {
  const res = await fetch(`/api/places?action=geocode&address=${encodeURIComponent(city + ', Brasil')}`)
  const data = await res.json()
  if (data.results?.[0]) return data.results[0].geometry.location
  return { lat: -15.8, lng: -47.9 }
}

async function fetchPlaces(query: string, lat: number, lng: number, radius: number): Promise<any[]> {
  const res = await fetch(`/api/places?action=nearby&location=${lat},${lng}&radius=${radius}&keyword=${encodeURIComponent(query)}`)
  const data = await res.json()
  return data.results || []
}

async function fetchDetails(placeId: string): Promise<{ website?: string; phone?: string }> {
  const res = await fetch(`/api/places?action=details&place_id=${encodeURIComponent(placeId)}`)
  const data = await res.json()
  return { website: data.result?.website, phone: data.result?.formatted_phone_number }
}

function generateWaMsg(place: PlaceResult, service: string): string {
  const meta = SERVICE_META[service] || SERVICE_META.outros
  return encodeURIComponent(meta.waMsg(place.name))
}

export function SearchResults({ params, userId, plan = 'free', onLimitReached }: { params: SearchParams; userId: string | null; plan?: Plan; onLimitReached: () => void }) {
  const [results, setResults] = useState<PlaceResult[]>([])
  const [loading, setLoading] = useState(false)
  const [searched, setSearched] = useState(false)
  const [error, setError] = useState('')
  const [exported, setExported] = useState(false)

  const meta = SERVICE_META[params.service] || SERVICE_META.outros
  const segQuery = SEGMENT_QUERIES[params.segment] || params.segment
  const maxResults = PLANS[plan]?.maxResults ?? 5

  const runSearch = useCallback(async () => {
    setLoading(true)
    setError('')
    setSearched(false)
    setResults([])

    try {
      // Check limit server-side first
      const limitRes = await fetch('/api/search', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ checkOnly: true, ...params }),
      })
      if (limitRes.status === 403) { onLimitReached(); setLoading(false); return }

      // Geocode city
      let lat = -15.8, lng = -47.9
      if (!params.allBrazil && params.city) {
        const loc = await geocodeCity(params.city)
        lat = loc.lat; lng = loc.lng
      }

      const radius = params.allBrazil ? 50000 : 20000
      const raw = await fetchPlaces(segQuery, lat, lng, radius)

      if (!raw.length) { setResults([]); setSearched(true); setLoading(false); return }

      // New API returns website/phone directly in nearby results
      const limit = maxResults === null ? 20 : maxResults
      const detailed: PlaceResult[] = raw.slice(0, limit).map((p: any) => ({
        name: p.name,
        address: p.vicinity || '',
        rating: p.rating || 0,
        reviews: p.user_ratings_total || 0,
        website: p.website || '',
        phone: p.formatted_phone_number || '',
        isOpen: p.opening_hours?.open_now ?? null,
      }))

      // Apply service filter
      const filtered = meta.filterFn ? detailed.filter(p => meta.filterFn({ website: p.website || undefined })) : detailed
      setResults(filtered)

      // Increment counter server-side
      if (userId) {
        fetch('/api/search', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ countOnly: true, ...params }),
        }).catch(() => {})
      }
    } catch (e) {
      setError('Erro na busca. Verifique sua conexão.')
    } finally {
      setLoading(false)
      setSearched(true)
    }
  }, [params, meta, segQuery, userId, onLimitReached])

  async function handleExport() {
    const { utils, writeFile } = await import('xlsx')
    const rows = results.map(r => ({
      Nome: r.name,
      Endereço: r.address || '',
      Avaliação: r.rating || '',
      Avaliações: r.reviews || '',
      Site: r.website || 'SEM SITE',
      Telefone: r.phone || '',
    }))
    const ws = utils.json_to_sheet(rows)
    const wb = utils.book_new()
    utils.book_append_sheet(wb, ws, 'Leads')
    writeFile(wb, `leads-honkponk-${params.segment}-${params.city || 'brasil'}.xlsx`)
    setExported(true)
  }

  if (!searched && !loading) {
    return (
      <div style={{ textAlign: 'center', padding: '60px 24px' }}>
        <div style={{ fontSize: '3rem', marginBottom: 16 }}>{meta.icon}</div>
        <h3 style={{ fontSize: '1.3rem', fontWeight: 800, marginBottom: 8 }}>{meta.name}</h3>
        <p style={{ color: 'rgba(255,255,255,.5)', marginBottom: 28, maxWidth: 420, margin: '0 auto 28px' }}>{meta.filterLabel}</p>
        <button onClick={runSearch} style={{ background: 'linear-gradient(135deg,#e879a0,#c2185b)', color: '#fff', border: 'none', borderRadius: 14, padding: '16px 36px', fontSize: '1rem', fontWeight: 700, cursor: 'pointer', fontFamily: 'inherit', boxShadow: '0 8px 30px rgba(232,121,160,.35)' }}>
          🔍 Buscar leads agora
        </button>
      </div>
    )
  }

  if (loading) {
    return (
      <div style={{ textAlign: 'center', padding: '80px 24px' }}>
        <div className="spinner" style={{ margin: '0 auto 20px' }} />
        <p style={{ color: 'rgba(255,255,255,.5)' }}>Buscando leads{!params.allBrazil && params.city ? ` em ${params.city}` : ' no Brasil'}...</p>
      </div>
    )
  }

  if (error) {
    return (
      <div style={{ textAlign: 'center', padding: '60px 24px' }}>
        <p style={{ color: '#fb923c', marginBottom: 16 }}>{error}</p>
        <button onClick={runSearch} style={{ background: 'rgba(255,255,255,.08)', color: '#fff', border: '1px solid rgba(255,255,255,.15)', borderRadius: 12, padding: '12px 24px', fontSize: '.9rem', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}>Tentar novamente</button>
      </div>
    )
  }

  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20, flexWrap: 'wrap', gap: 12 }}>
        <div>
          <span style={{ fontSize: '.75rem', fontWeight: 700, color: '#e879a0', textTransform: 'uppercase', letterSpacing: 1 }}>{results.length} leads encontrados</span>
          <p style={{ fontSize: '.8rem', color: 'rgba(255,255,255,.4)', marginTop: 2 }}>{meta.filterLabel}</p>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <button onClick={runSearch} style={{ background: 'rgba(255,255,255,.06)', color: 'rgba(255,255,255,.7)', border: '1px solid rgba(255,255,255,.1)', borderRadius: 10, padding: '9px 16px', fontSize: '.82rem', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}>↻ Atualizar</button>
          {results.length > 0 && (
            <button onClick={handleExport} style={{ background: exported ? 'rgba(74,222,128,.15)' : 'rgba(255,255,255,.06)', color: exported ? '#4ade80' : 'rgba(255,255,255,.7)', border: `1px solid ${exported ? 'rgba(74,222,128,.3)' : 'rgba(255,255,255,.1)'}`, borderRadius: 10, padding: '9px 16px', fontSize: '.82rem', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}>
              {exported ? '✓ Exportado' : '⬇ Excel'}
            </button>
          )}
        </div>
      </div>

      {results.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '60px 24px', color: 'rgba(255,255,255,.4)' }}>
          <div style={{ fontSize: '2.5rem', marginBottom: 12 }}>🔍</div>
          <p>Nenhum lead encontrado com esse filtro. Tente outra cidade ou segmento.</p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {results.map((place, i) => (
            <div key={i} style={{ background: 'rgba(255,255,255,.04)', border: '1px solid rgba(248,182,200,0.14)', borderRadius: 14, padding: '16px 20px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 16, flexWrap: 'wrap' }}>
              <div style={{ flex: 1, minWidth: 200 }}>
                <div style={{ fontWeight: 700, marginBottom: 3 }}>{place.name}</div>
                <div style={{ fontSize: '.78rem', color: 'rgba(255,255,255,.4)', marginBottom: 6 }}>{place.address}</div>
                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                  {place.rating > 0 && <span style={{ fontSize: '.7rem', background: 'rgba(255,200,0,.1)', color: '#fbbf24', borderRadius: 6, padding: '2px 8px' }}>⭐ {place.rating} ({place.reviews})</span>}
                  {!place.website ? <span style={{ fontSize: '.7rem', background: 'rgba(232,121,160,.12)', color: '#e879a0', borderRadius: 6, padding: '2px 8px' }}>Sem site</span> : <span style={{ fontSize: '.7rem', background: 'rgba(74,222,128,.1)', color: '#4ade80', borderRadius: 6, padding: '2px 8px' }}>Tem site</span>}
                  {place.isOpen === true && <span style={{ fontSize: '.7rem', background: 'rgba(74,222,128,.1)', color: '#4ade80', borderRadius: 6, padding: '2px 8px' }}>Aberto</span>}
                </div>
              </div>
              <div style={{ display: 'flex', gap: 8, flexShrink: 0, flexWrap: 'wrap' }}>
                {place.phone && (
                  <a href={`https://wa.me/55${place.phone.replace(/\D/g,'')}?text=${generateWaMsg(place, params.service)}`} target="_blank" rel="noopener noreferrer"
                    style={{ background: 'rgba(37,211,102,.15)', color: '#25d366', border: '1px solid rgba(37,211,102,.25)', borderRadius: 10, padding: '8px 14px', fontSize: '.78rem', fontWeight: 700, textDecoration: 'none', whiteSpace: 'nowrap' }}>
                    WhatsApp
                  </a>
                )}
                <a href={`https://www.google.com/search?q=${encodeURIComponent(place.name + ' instagram')}`} target="_blank" rel="noopener noreferrer"
                  style={{ background: 'rgba(225,48,108,.15)', color: '#e1306c', border: '1px solid rgba(225,48,108,.25)', borderRadius: 10, padding: '8px 14px', fontSize: '.78rem', fontWeight: 700, textDecoration: 'none', whiteSpace: 'nowrap' }}>
                  Instagram
                </a>
                {place.website && (
                  <a href={place.website} target="_blank" rel="noopener noreferrer"
                    style={{ background: 'rgba(255,255,255,.06)', color: 'rgba(255,255,255,.6)', border: '1px solid rgba(255,255,255,.1)', borderRadius: 10, padding: '8px 14px', fontSize: '.78rem', fontWeight: 600, textDecoration: 'none' }}>
                    Site
                  </a>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
