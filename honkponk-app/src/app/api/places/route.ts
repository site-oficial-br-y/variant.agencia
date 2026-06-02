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
    const radius = parseFloat(searchParams.get('radius') || '20000')
    const keyword = searchParams.get('keyword') || ''
    const [lat, lng] = location.split(',').map(Number)

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
