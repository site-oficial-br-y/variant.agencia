import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'
import { GoogleAnalytics } from '@/components/GoogleAnalytics'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'Honk Ponk — Prospecção B2B Inteligente',
  description: 'Encontre clientes antes da concorrência. Honk Ponk rastreia negócios por região e filtra leads que realmente precisam do seu serviço.',
  icons: { icon: 'https://site-oficial-br-y.github.io/Honkponk/logo.png' },
  verification: { google: 'google-site-verification-code' },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-BR">
      <body className={inter.className}>
        <GoogleAnalytics gaId={process.env.NEXT_PUBLIC_GA_ID || 'G-GN8WFCHBL0'} />
        {children}
      </body>
    </html>
  )
}
