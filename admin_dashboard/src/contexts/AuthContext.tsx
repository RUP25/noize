/* eslint-disable react-refresh/only-export-components */
import React, { createContext, useContext, useState, useEffect } from 'react'
import { api } from '../services/api'

interface AuthContextType {
  isAuthenticated: boolean
  token: string | null
  login: (email: string, password: string) => Promise<void>
  logout: () => void
}

const AuthContext = createContext<AuthContextType | undefined>(undefined)

export function AuthProvider({ children }: { children: React.ReactNode }) {
  console.log('AuthProvider rendering...')
  const [token, setToken] = useState<string | null>(() => {
    try {
      return localStorage.getItem('admin_token')
    } catch (error) {
      console.warn('Could not access localStorage:', error)
      return null
    }
  })

  useEffect(() => {
    if (token) {
      api.defaults.headers.common['Authorization'] = `Bearer ${token}`
    } else {
      delete api.defaults.headers.common['Authorization']
    }
  }, [token])

  const login = async (email: string, password: string) => {
    try {
      console.log('Attempting login...')
      const response = await api.post('/auth/login/email', { email, password })
      const newToken = response.data.access_token
      console.log('Login successful, token received:', newToken ? 'yes' : 'no')
      
      // Update localStorage first
      localStorage.setItem('admin_token', newToken)
      
      // Then update state (this will trigger re-render)
      setToken(newToken)
      
      // Update API headers
      api.defaults.headers.common['Authorization'] = `Bearer ${newToken}`
      
      console.log('Token set, isAuthenticated should be:', !!newToken)
    } catch (error: any) {
      console.error('Login error:', error)
      throw new Error(error.response?.data?.detail || 'Login failed')
    }
  }

  const logout = () => {
    setToken(null)
    localStorage.removeItem('admin_token')
    delete api.defaults.headers.common['Authorization']
  }

  return (
    <AuthContext.Provider
      value={{ isAuthenticated: !!token, token, login, logout }}
    >
      {children}
    </AuthContext.Provider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (!context) {
    throw new Error('useAuth must be used within AuthProvider')
  }
  return context
}
