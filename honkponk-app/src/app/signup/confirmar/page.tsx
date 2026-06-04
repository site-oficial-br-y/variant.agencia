'use client'
import { useEffect } from 'react'
import { useRouter } from 'next/navigation'

export default function ConfirmarPage() {
  const router = useRouter()
  useEffect(() => { router.replace('/dashboard') }, [router])
  return <div style={{ minHeight: '100vh', background: '#0f0f1a' }} />
}

