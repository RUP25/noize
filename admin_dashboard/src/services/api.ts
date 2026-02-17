import axios from 'axios'

export const api = axios.create({
  baseURL: '/api',
  headers: {
    'Content-Type': 'application/json',
  },
})

// Add auth token from localStorage if available
// Use try-catch to handle cases where localStorage might not be available
try {
  const token = localStorage.getItem('admin_token')
  if (token) {
    api.defaults.headers.common['Authorization'] = `Bearer ${token}`
  }
} catch (error) {
  console.warn('Could not access localStorage:', error)
}

// Response interceptor for error handling
api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (error.response?.status === 401) {
      localStorage.removeItem('admin_token')
      window.location.href = '/login'
    }
    
    // Improve error messages for connection issues
    if (error.code === 'ECONNREFUSED' || error.message?.includes('socket hang up') || error.message?.includes('Network Error')) {
      const improvedError = new Error('Cannot connect to backend server. Make sure the backend is running at http://localhost:8000')
      improvedError.name = 'ConnectionError'
      return Promise.reject(improvedError)
    }
    
    return Promise.reject(error)
  }
)
