'use client'
import { useState, useCallback } from 'react'
import Link from 'next/link'
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

const BRAZIL_CITIES = [
  { lat: -23.55, lng: -46.63 }, // São Paulo
  { lat: -22.91, lng: -43.17 }, // Rio de Janeiro
  { lat: -19.92, lng: -43.94 }, // Belo Horizonte
  { lat: -30.03, lng: -51.23 }, // Porto Alegre
  { lat: -12.97, lng: -38.50 }, // Salvador
  { lat: -3.72,  lng: -38.54 }, // Fortaleza
  { lat: -8.05,  lng: -34.88 }, // Recife
  { lat: -15.78, lng: -47.93 }, // Brasília
  { lat: -1.46,  lng: -48.50 }, // Belém
  { lat: -3.10,  lng: -60.02 }, // Manaus
]

async function fetchPlacesBrazil(query: string): Promise<any[]> {
  const batches = await Promise.all(
    BRAZIL_CITIES.map(c => fetchPlaces(query, c.lat, c.lng, 30000))
  )
  const seen = new Set<string>()
  const merged: any[] = []
  for (const batch of batches) {
    for (const p of batch) {
      const key = p.name + (p.vicinity || '')
      if (!seen.has(key)) { seen.add(key); merged.push(p) }
    }
  }
  return merged
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
  const canExport = PLANS[plan]?.exportExcel ?? false

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

      const raw = params.allBrazil
        ? await fetchPlacesBrazil(segQuery)
        : await fetchPlaces(segQuery, lat, lng, 20000)

      if (!raw.length) { setResults([]); setSearched(true); setLoading(false); return }

      // New API returns website/phone directly in nearby results
      const detailed: PlaceResult[] = raw.map((p: any) => ({
        name: p.name,
        address: p.vicinity || '',
        rating: p.rating || 0,
        reviews: p.user_ratings_total || 0,
        website: p.website || '',
        phone: p.formatted_phone_number || '',
        isOpen: p.opening_hours?.open_now ?? null,
      }))

      // Apply service filter, then cap to plan limit
      const filtered = meta.filterFn ? detailed.filter(p => meta.filterFn({ website: p.website || undefined })) : detailed
      const limit = maxResults === null ? filtered.length : maxResults
      setResults(filtered.slice(0, limit))

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
      <div style={{ padding: '40px 0' }}>
        {/* Animated loading header */}
        <div style={{ display: 'flex', alignItems: 'center', gap: 14, marginBottom: 28, padding: '18px 22px', background: 'rgba(232,121,160,.06)', border: '1px solid rgba(232,121,160,.15)', borderRadius: 16 }}>
          <div style={{ width: 38, height: 38, borderRadius: 10, background: 'rgba(232,121,160,.15)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
            <div className="spinner" style={{ margin: 0 }} />
          </div>
          <div>
            <div style={{ fontWeight: 700, fontSize: '.95rem', marginBottom: 3 }}>Buscando leads…</div>
            <div style={{ fontSize: '.78rem', color: 'rgba(255,255,255,.4)' }}>
              {params.allBrazil ? 'Varrendo as 10 maiores cidades do Brasil' : `Pesquisando em ${params.city}`}
            </div>
          </div>
          <div style={{ marginLeft: 'auto', display: 'flex', gap: 4 }}>
            {[0,1,2].map(i => (
              <div key={i} style={{ width: 7, height: 7, borderRadius: '50%', background: '#e879a0', animation: `blink 1.2s ease-in-out ${i * 0.2}s infinite` }} />
            ))}
          </div>
        </div>
        {/* Skeleton cards */}
        {[1,2,3].map(i => (
          <div key={i} style={{ background: 'rgba(255,255,255,.03)', border: '1px solid rgba(255,255,255,.07)', borderRadius: 16, padding: '18px 22px', marginBottom: 10, display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 16, opacity: 1 - i * 0.2 }}>
            <div style={{ flex: 1 }}>
              <div style={{ height: 14, width: '55%', background: 'rgba(255,255,255,.07)', borderRadius: 6, marginBottom: 10, animation: 'pulse 1.5s ease-in-out infinite' }} />
              <div style={{ height: 11, width: '80%', background: 'rgba(255,255,255,.05)', borderRadius: 6, marginBottom: 10 }} />
              <div style={{ display: 'flex', gap: 6 }}>
                <div style={{ height: 20, width: 60, background: 'rgba(255,255,255,.05)', borderRadius: 6 }} />
                <div style={{ height: 20, width: 50, background: 'rgba(255,255,255,.05)', borderRadius: 6 }} />
              </div>
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <div style={{ height: 34, width: 90, background: 'rgba(255,255,255,.05)', borderRadius: 10 }} />
              <div style={{ height: 34, width: 80, background: 'rgba(255,255,255,.05)', borderRadius: 10 }} />
            </div>
          </div>
        ))}
        <style>{`@keyframes pulse { 0%,100%{opacity:.6} 50%{opacity:1} }`}</style>
      </div>
    )
  }

  if (error) {
    return (
      <div style={{ textAlign: 'center', padding: '60px 24px', background: 'rgba(251,146,60,.05)', border: '1px solid rgba(251,146,60,.15)', borderRadius: 16 }}>
        <div style={{ fontSize: '2rem', marginBottom: 12 }}>⚠️</div>
        <p style={{ color: '#fb923c', marginBottom: 20, fontWeight: 600 }}>{error}</p>
        <button onClick={runSearch} style={{ background: 'rgba(255,255,255,.08)', color: '#fff', border: '1px solid rgba(255,255,255,.15)', borderRadius: 12, padding: '12px 24px', fontSize: '.9rem', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}>Tentar novamente</button>
      </div>
    )
  }

  return (
    <div>
      {/* Results header bar */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 16, flexWrap: 'wrap', gap: 10 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div style={{ background: 'linear-gradient(135deg,#e879a0,#c2185b)', borderRadius: 8, padding: '6px 12px', fontSize: '.75rem', fontWeight: 800, letterSpacing: .5 }}>
            {results.length} leads
          </div>
          <span style={{ fontSize: '.8rem', color: 'rgba(255,255,255,.35)' }}>{meta.filterLabel}</span>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button onClick={runSearch} style={{ background: 'rgba(255,255,255,.05)', color: 'rgba(255,255,255,.6)', border: '1px solid rgba(255,255,255,.1)', borderRadius: 10, padding: '8px 14px', fontSize: '.8rem', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}>↻ Atualizar</button>
          {results.length > 0 && canExport && (
            <button onClick={handleExport} style={{ background: exported ? 'rgba(74,222,128,.12)' : 'rgba(255,255,255,.05)', color: exported ? '#4ade80' : 'rgba(255,255,255,.6)', border: `1px solid ${exported ? 'rgba(74,222,128,.25)' : 'rgba(255,255,255,.1)'}`, borderRadius: 10, padding: '8px 14px', fontSize: '.8rem', fontWeight: 600, cursor: 'pointer', fontFamily: 'inherit' }}>
              {exported ? '✓ Exportado' : '⬇ Excel'}
            </button>
          )}
          {results.length > 0 && !canExport && (
            <Link href="/#precos" style={{ background: 'rgba(255,255,255,.04)', color: 'rgba(255,255,255,.3)', border: '1px solid rgba(255,255,255,.08)', borderRadius: 10, padding: '8px 14px', fontSize: '.8rem', fontWeight: 600, textDecoration: 'none', display: 'inline-flex', alignItems: 'center', gap: 5 }}>
              🔒 Excel
            </Link>
          )}
        </div>
      </div>

      {results.length === 0 ? (
        <div style={{ textAlign: 'center', padding: '60px 24px', background: 'rgba(255,255,255,.02)', border: '1px dashed rgba(255,255,255,.1)', borderRadius: 16, color: 'rgba(255,255,255,.4)' }}>
          <div style={{ fontSize: '2.5rem', marginBottom: 12 }}>🔍</div>
          <p style={{ fontWeight: 600, marginBottom: 6 }}>Nenhum lead encontrado</p>
          <p style={{ fontSize: '.82rem' }}>Tente outra cidade ou segmento.</p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
          {results.map((place, i) => (
            <div key={i} className="lead-card" style={{ background: 'rgba(255,255,255,.03)', border: '1px solid rgba(248,182,200,.1)', borderRadius: 16, padding: '16px 20px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 16, flexWrap: 'wrap', transition: 'border-color .2s, background .2s', animation: `fadeUp .4s ease ${Math.min(i * 0.06, 0.4)}s both` }}>
              {/* Index badge + info */}
              <div style={{ display: 'flex', alignItems: 'flex-start', gap: 14, flex: 1, minWidth: 200 }}>
                <div style={{ width: 32, height: 32, borderRadius: 10, background: 'rgba(232,121,160,.1)', border: '1px solid rgba(232,121,160,.2)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '.72rem', fontWeight: 800, color: '#e879a0', flexShrink: 0 }}>
                  {i + 1}
                </div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 700, fontSize: '.95rem', marginBottom: 4 }}>{place.name}</div>
                  {place.address && <div style={{ fontSize: '.75rem', color: 'rgba(255,255,255,.35)', marginBottom: 8 }}>{place.address}</div>}
                  <div style={{ display: 'flex', gap: 5, flexWrap: 'wrap' }}>
                    {place.rating > 0 && (
                      <span style={{ fontSize: '.68rem', background: 'rgba(251,191,36,.1)', color: '#fbbf24', borderRadius: 6, padding: '3px 8px', fontWeight: 600 }}>⭐ {place.rating} ({place.reviews})</span>
                    )}
                    {!place.website
                      ? <span style={{ fontSize: '.68rem', background: 'rgba(232,121,160,.12)', color: '#e879a0', borderRadius: 6, padding: '3px 8px', fontWeight: 600 }}>Sem site</span>
                      : <span style={{ fontSize: '.68rem', background: 'rgba(74,222,128,.1)', color: '#4ade80', borderRadius: 6, padding: '3px 8px', fontWeight: 600 }}>Tem site</span>
                    }
                    {place.isOpen === true && <span style={{ fontSize: '.68rem', background: 'rgba(74,222,128,.1)', color: '#4ade80', borderRadius: 6, padding: '3px 8px', fontWeight: 600 }}>Aberto agora</span>}
                    {place.phone && <span style={{ fontSize: '.68rem', background: 'rgba(255,255,255,.06)', color: 'rgba(255,255,255,.5)', borderRadius: 6, padding: '3px 8px' }}>{place.phone}</span>}
                  </div>
                </div>
              </div>
              {/* Action buttons */}
              <div style={{ display: 'flex', gap: 7, flexShrink: 0, flexWrap: 'wrap' }}>
                {place.phone && (
                  <a href={`https://wa.me/55${place.phone.replace(/\D/g,'')}?text=${generateWaMsg(place, params.service)}`} target="_blank" rel="noopener noreferrer"
                    style={{ background: 'rgba(37,211,102,.12)', color: '#25d366', border: '1px solid rgba(37,211,102,.22)', borderRadius: 10, padding: '8px 16px', fontSize: '.78rem', fontWeight: 700, textDecoration: 'none', whiteSpace: 'nowrap', display: 'inline-flex', alignItems: 'center', gap: 5 }}>
                    <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor"><path d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/></svg>
                    WhatsApp
                  </a>
                )}
                <a href={`https://www.google.com/search?q=${encodeURIComponent(place.name + ' instagram')}`} target="_blank" rel="noopener noreferrer"
                  style={{ background: 'rgba(225,48,108,.12)', color: '#e1306c', border: '1px solid rgba(225,48,108,.22)', borderRadius: 10, padding: '8px 16px', fontSize: '.78rem', fontWeight: 700, textDecoration: 'none', whiteSpace: 'nowrap', display: 'inline-flex', alignItems: 'center', gap: 5 }}>
                  <svg width="13" height="13" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z"/></svg>
                  Instagram
                </a>
                {place.website && (
                  <a href={place.website} target="_blank" rel="noopener noreferrer"
                    style={{ background: 'rgba(255,255,255,.05)', color: 'rgba(255,255,255,.55)', border: '1px solid rgba(255,255,255,.1)', borderRadius: 10, padding: '8px 14px', fontSize: '.78rem', fontWeight: 600, textDecoration: 'none', whiteSpace: 'nowrap' }}>
                    Site ↗
                  </a>
                )}
              </div>
            </div>
          ))}
        </div>
      )}
      <style>{`
        .lead-card:hover { border-color: rgba(248,182,200,.25) !important; background: rgba(255,255,255,.05) !important; }
      `}</style>
    </div>
  )
}
