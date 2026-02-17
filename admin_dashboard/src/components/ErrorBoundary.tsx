import React, { Component, ErrorInfo, ReactNode } from 'react'

interface Props {
  children: ReactNode
}

interface State {
  hasError: boolean
  error: Error | null
}

export class ErrorBoundary extends Component<Props, State> {
  public state: State = {
    hasError: false,
    error: null,
  }

  public static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error }
  }

  public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('Uncaught error:', error, errorInfo)
  }

  public render() {
    if (this.state.hasError) {
      return (
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            minHeight: '100vh',
            backgroundColor: '#0f1419',
            color: '#e0e0e0',
            padding: '40px',
          }}
        >
          <h1 style={{ color: '#f56565', marginBottom: '16px' }}>Something went wrong</h1>
          <p style={{ color: '#a0aec0', marginBottom: '24px' }}>
            {this.state.error?.message || 'An unexpected error occurred'}
          </p>
          <button
            onClick={() => window.location.reload()}
            style={{
              padding: '12px 24px',
              backgroundColor: '#78e08f',
              color: '#0f1419',
              border: 'none',
              borderRadius: '8px',
              cursor: 'pointer',
              fontWeight: '600',
            }}
          >
            Reload Page
          </button>
          <details style={{ marginTop: '24px', color: '#a0aec0', maxWidth: '600px' }}>
            <summary style={{ cursor: 'pointer', marginBottom: '8px' }}>Error Details</summary>
            <pre
              style={{
                backgroundColor: '#1a1f2e',
                padding: '16px',
                borderRadius: '8px',
                overflow: 'auto',
                fontSize: '12px',
              }}
            >
              {this.state.error?.stack}
            </pre>
          </details>
        </div>
      )
    }

    return this.props.children
  }
}
