import { NextRequest, NextResponse } from 'next/server'

const GOOGLE_KEY = process.env.GOOGLE_PLACES_KEY || ''

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url)
  const action = searchParams.get('action')

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
    const radius = searchParams.get('radius') || '20000'
    const keyword = searchParams.get('keyword') || ''
    const res = await fetch(
      `https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${location}&radius=${radius}&keyword=${encodeURIComponent(keyword)}&key=${GOOGLE_KEY}&language=pt-BR`
    )
    const data = await res.json()
    return NextResponse.json(data)
  }

  if (action === 'test') {
    const keyPreview = GOOGLE_KEY ? `${GOOGLE_KEY.slice(0, 8)}...` : 'NOT SET'
    const geoRes = await fetch(`https://maps.googleapis.com/maps/api/geocode/json?address=Santos,Brasil&key=${GOOGLE_KEY}`)
    const geoData = await geoRes.json()
    let nearbyStatus = 'not tested'
    if (geoData.results?.[0]) {
      const { lat, lng } = geoData.results[0].geometry.location
      const nearbyRes = await fetch(`https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=${lat},${lng}&radius=20000&keyword=restaurantes&key=${GOOGLE_KEY}&language=pt-BR`)
      const nearbyData = await nearbyRes.json()
      nearbyStatus = nearbyData.status + (nearbyData.error_message ? `: ${nearbyData.error_message}` : '') + ` (${nearbyData.results?.length ?? 0} results)`
    }
    return NextResponse.json({ keyPreview, geocodeStatus: geoData.status, nearbyStatus })
  }

  if (action === 'details') {
    const placeId = searchParams.get('place_id') || ''
    const res = await fetch(
      `https://maps.googleapis.com/maps/api/place/details/json?place_id=${placeId}&fields=website,formatted_phone_number&key=${GOOGLE_KEY}`
    )
    const data = await res.json()
    return NextResponse.json(data)
  }

  return NextResponse.json({ error: 'Invalid action' }, { status: 400 })
}
