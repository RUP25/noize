import React from 'react'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import Login from './pages/Login'
import Dashboard from './pages/Dashboard'
import ContentModeration from './pages/ContentModeration'
import FlaggedCenter from './pages/FlaggedCenter'
import UserManagement from './pages/UserManagement'
import Analytics from './pages/Analytics'
import Settings from './pages/Settings'
import Layout from './components/Layout'
import { AuthProvider, useAuth } from './contexts/AuthContext'

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { isAuthenticated } = useAuth()
  // Check localStorage directly as a fallback for immediate navigation
  const [mounted, setMounted] = React.useState(false)
  
  React.useEffect(() => {
    setMounted(true)
  }, [])
  
  // On first render, check localStorage directly
  const hasToken = React.useMemo(() => {
    if (!mounted) return false
    try {
      return !!localStorage.getItem('admin_token')
    } catch {
      return false
    }
  }, [mounted, isAuthenticated]) // Re-check when isAuthenticated changes
  
  const authenticated = isAuthenticated || hasToken
  
  if (!authenticated) {
    return <Navigate to="/login" replace />
  }
  
  return <>{children}</>
}

function AppRoutes() {
  console.log('AppRoutes rendering...')
  try {
    return (
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route
          path="/"
          element={
            <ProtectedRoute>
              <Layout />
            </ProtectedRoute>
          }
        >
          <Route index element={<Dashboard />} />
          <Route path="content" element={<ContentModeration />} />
          <Route path="flagged" element={<FlaggedCenter />} />
          <Route path="users" element={<UserManagement />} />
          <Route path="analytics" element={<Analytics />} />
          <Route path="settings" element={<Settings />} />
        </Route>
      </Routes>
    )
  } catch (error) {
    console.error('Error in AppRoutes:', error)
    return (
      <div style={{ padding: '40px', color: '#f56565' }}>
        <h1>Error in AppRoutes</h1>
        <pre>{error instanceof Error ? error.message : String(error)}</pre>
      </div>
    )
  }
}

function App() {
  console.log('App component rendering...')
  return (
    <BrowserRouter>
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>
    </BrowserRouter>
  )
}

export default App
