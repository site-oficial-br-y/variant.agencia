'use client'
import { useState, useCallback } from 'react'
import { SEGMENT_QUERIES, SERVICE_META } from '@/lib/search'
import type { PlaceResult } from '@/lib/search'

interface SearchParams { service: string; city: string; segment: string; allBrazil: boolean }

const GOOGLE_KEY = process.env.NEXT_PUBLIC_GOOGLE_PLACES_KEY || ''

async function geocodeCity(city: string): Promise<{ lat: number; lng: number } | null> {
  const res = await fetch(
    `https://maps.googleapis.com/maps/api/geocode/json?address=${encodeURIComponent(city + ', Brasil')}&key=${GOOGLE_KEY}`
  )
  const data = await res.json()
  if (data.results?.[0]) return data.results[0].geometry.location
  return null
}

async function fetchPlaces(query: string, lat: number, lng: number, radius: number): Promise<PlaceResult[]> {
  const res = await fetch(
    `https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${lat},${lng}&radius=${radius}&keyword=${encodeURIComponent(query)}&key=${GOOGLE_KEY}`
  )
  const data = await res.json()
  return (data.results || []).map((p: any) => ({
    place_id: p.place_id,
    name: p.name,
    address: p.vicinity,
    rating: p.rating,
    user_ratings_total: p.user_ratings_total,
    website: p.website,
    phone: p.formatted_phone_number,
    types: p.types,
    business_status: p.business_status,
  }))
}

function generateWaMsg(place: PlaceResult, service: string): string {
  const meta = SERVICE_META[service] || SERVICE_META.outros
  return encodeURIComponent(meta.waMsg(place.name))
}

export function SearchResults({ params, userId, onLimitReached }: { params: SearchParams; userId: string | null; onLimitReached: () => void }) {
  const [results, setResults] = useState<PlaceResult[]>([])
  const [loading, setLoading] = useState(false)
  const [searched, setSearched] = useState(false)
  const [error, setError] = useState('')
  const [exported, setExported] = useState(false)

  const meta = SERVICE_META[params.service] || SERVICE_META.outros
  const segConfig = SEGMENT_QUERIES[params.segment]

  const runSearch = useCallback(async () => {
    setLoading(true)
    setError('')
    setSearched(false)
    setResults([])

    try {
      const res = await fetch('/api/search', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(params),
      })
      const data = await res.json()

      if (res.status === 403) { onLimitReached(); return }
      if (!res.ok) { setError(data.error || 'Erro na busca.'); return }

      const places: PlaceResult[] = data.results || []
      const filtered = meta.filterFn ? places.filter(meta.filterFn) : places
      setResults(filtered)
    } catch {
      setError('Erro de conexão.')
    } finally {
      setLoading(false)
      setSearched(true)
    }
  }, [params, meta, onLimitReached])

  async function handleExport() {
    const { utils, writeFile } = await import('xlsx')
    const rows = results.map(r => ({
      Nome: r.name,
      Endereço: r.address || '',
      Avaliação: r.rating || '',
      Avaliações: r.user_ratings_total || '',
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
        <p style={{ color: 'rgba(255,255,255,.5)' }}>Buscando leads em {params.allBrazil ? 'todo o Brasil' : params.city}...</p>
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
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 24, flexWrap: 'wrap', gap: 12 }}>
        <div>
          <span style={{ fontSize: '.75rem', fontWeight: 700, color: '#e879a0', textTransform: 'uppercase', letterSpacing: 1 }}>{results.length} leads encontrados</span>
          <p style={{ fontSize: '.82rem', color: 'rgba(255,255,255,.4)', marginTop: 2 }}>{meta.filterLabel}</p>
        </div>
        <div style={{ display: 'flex', gap: 10 }}>
          <button onClick={runSearch} style={{ background: 'rgba(255,255,255,.06)', color: 'rgba(255,255,255,.7)', border: '1px solid rgba(255,255,255,.1)', borderRadius: 10, padding: '9px 16px', fontSize: '.82rem', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}>↻ Nova busca</button>
          {results.length > 0 && (
            <button onClick={handleExport} style={{ background: exported ? 'rgba(74,222,128,.15)' : 'rgba(255,255,255,.06)', color: exported ? '#4ade80' : 'rgba(255,255,255,.7)', border: `1px solid ${exported ? 'rgba(74,222,128,.3)' : 'rgba(255,255,255,.1)'}`, borderRadius: 10, padding: '9px 16px', fontSize: '.82rem', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}>
              {exported ? '✓ Exportado' : '⬇ Exportar Excel'}
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
        <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {results.map(place => (
            <div key={place.place_id} style={{ background: 'rgba(255,255,255,.04)', border: '1px solid rgba(248,182,200,0.14)', borderRadius: 16, padding: '18px 20px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 16, flexWrap: 'wrap' }}>
              <div style={{ flex: 1, minWidth: 200 }}>
                <div style={{ fontWeight: 700, marginBottom: 4 }}>{place.name}</div>
                <div style={{ fontSize: '.8rem', color: 'rgba(255,255,255,.45)', marginBottom: 6 }}>{place.address}</div>
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                  {place.rating && <span style={{ fontSize: '.72rem', background: 'rgba(255,200,0,.1)', color: '#fbbf24', borderRadius: 6, padding: '2px 8px' }}>⭐ {place.rating} ({place.user_ratings_total})</span>}
                  {!place.website ? <span style={{ fontSize: '.72rem', background: 'rgba(232,121,160,.12)', color: '#e879a0', borderRadius: 6, padding: '2px 8px' }}>Sem site</span> : <span style={{ fontSize: '.72rem', background: 'rgba(74,222,128,.1)', color: '#4ade80', borderRadius: 6, padding: '2px 8px' }}>Tem site</span>}
                </div>
              </div>
              <div style={{ display: 'flex', gap: 8, flexShrink: 0 }}>
                {place.phone && (
                  <a href={`https://wa.me/55${place.phone.replace(/\D/g,'')}?text=${generateWaMsg(place, params.service)}`} target="_blank" rel="noopener noreferrer"
                    style={{ background: 'rgba(37,211,102,.15)', color: '#25d366', border: '1px solid rgba(37,211,102,.25)', borderRadius: 10, padding: '8px 14px', fontSize: '.8rem', fontWeight: 700, textDecoration: 'none', whiteSpace: 'nowrap' }}>
                    WhatsApp
                  </a>
                )}
                {place.website && (
                  <a href={place.website} target="_blank" rel="noopener noreferrer"
                    style={{ background: 'rgba(255,255,255,.06)', color: 'rgba(255,255,255,.6)', border: '1px solid rgba(255,255,255,.1)', borderRadius: 10, padding: '8px 14px', fontSize: '.8rem', fontWeight: 600, textDecoration: 'none' }}>
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
