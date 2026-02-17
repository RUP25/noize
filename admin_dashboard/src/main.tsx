import React from 'react'
import ReactDOM from 'react-dom/client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import App from './App.tsx'
import { ErrorBoundary } from './components/ErrorBoundary'
import './index.css'

const queryClient = new QueryClient()

const rootElement = document.getElementById('root')
if (!rootElement) {
  throw new Error('Root element not found')
}

console.log('Starting React app...')

try {
  ReactDOM.createRoot(rootElement).render(
    <React.StrictMode>
      <ErrorBoundary>
        <QueryClientProvider client={queryClient}>
          <App />
        </QueryClientProvider>
      </ErrorBoundary>
    </React.StrictMode>,
  )
  console.log('React app rendered successfully')
} catch (error) {
  console.error('Error rendering React app:', error)
  rootElement.innerHTML = `
    <div style="padding: 40px; color: #f56565; font-family: monospace;">
      <h1>Error Loading App</h1>
      <pre>${error instanceof Error ? error.message : String(error)}</pre>
      <pre>${error instanceof Error ? error.stack : ''}</pre>
    </div>
  `
}
