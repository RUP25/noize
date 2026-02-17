import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'

export default function Login() {
  console.log('Login component rendering...')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const { login } = useAuth()
  const navigate = useNavigate()

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setError('')
    setLoading(true)

    try {
      await login(email, password)
      // Wait a moment for state to update, then navigate
      // Using setTimeout to ensure state propagation
      setTimeout(() => {
        navigate('/', { replace: true })
      }, 50)
    } catch (err: any) {
      console.error('Login error:', err)
      setError(err.message || 'Login failed. Please check your credentials.')
      setLoading(false)
    }
  }

  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        minHeight: '100vh',
        backgroundColor: '#0f1419',
      }}
    >
      <div
        style={{
          width: '100%',
          maxWidth: '400px',
          padding: '32px',
          backgroundColor: '#1a1f2e',
          borderRadius: '12px',
          border: '1px solid #2d3748',
        }}
      >
        <h1
          style={{
            color: '#78e08f',
            fontSize: '28px',
            fontWeight: 'bold',
            marginBottom: '8px',
            textAlign: 'center',
          }}
        >
          NOIZE Admin
        </h1>
        <p
          style={{
            color: '#a0aec0',
            textAlign: 'center',
            marginBottom: '32px',
          }}
        >
          Content Management System
        </p>

        <form onSubmit={handleSubmit}>
          <div style={{ marginBottom: '20px' }}>
            <label
              htmlFor="email"
              style={{
                display: 'block',
                color: '#e0e0e0',
                marginBottom: '8px',
                fontSize: '14px',
              }}
            >
              Email
            </label>
            <input
              id="email"
              name="email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              autoComplete="email"
              required
              style={{
                width: '100%',
                padding: '12px',
                backgroundColor: '#0f1419',
                border: '1px solid #2d3748',
                borderRadius: '8px',
                color: '#e0e0e0',
                fontSize: '14px',
              }}
            />
          </div>

          <div style={{ marginBottom: '24px' }}>
            <label
              htmlFor="password"
              style={{
                display: 'block',
                color: '#e0e0e0',
                marginBottom: '8px',
                fontSize: '14px',
              }}
            >
              Password
            </label>
            <input
              id="password"
              name="password"
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              autoComplete="current-password"
              required
              style={{
                width: '100%',
                padding: '12px',
                backgroundColor: '#0f1419',
                border: '1px solid #2d3748',
                borderRadius: '8px',
                color: '#e0e0e0',
                fontSize: '14px',
              }}
            />
          </div>

          {error && (
            <div
              style={{
                padding: '12px',
                backgroundColor: '#742a2a',
                border: '1px solid #e53e3e',
                borderRadius: '8px',
                color: '#fc8181',
                marginBottom: '20px',
                fontSize: '14px',
              }}
            >
              {error}
            </div>
          )}

          <button
            type="submit"
            disabled={loading}
            style={{
              width: '100%',
              padding: '12px',
              backgroundColor: '#78e08f',
              color: '#0f1419',
              border: 'none',
              borderRadius: '8px',
              fontSize: '16px',
              fontWeight: '600',
              cursor: loading ? 'not-allowed' : 'pointer',
              opacity: loading ? 0.6 : 1,
            }}
          >
            {loading ? 'Logging in...' : 'Login'}
          </button>
        </form>
      </div>
    </div>
  )
}
