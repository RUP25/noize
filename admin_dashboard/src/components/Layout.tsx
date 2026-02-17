import { Outlet, Link, useLocation } from 'react-router-dom'
import { useAuth } from '../contexts/AuthContext'
import {
  LayoutDashboard,
  FileText,
  Users,
  BarChart3,
  Settings,
  LogOut,
  Flag,
} from 'lucide-react'

export default function Layout() {
  const { logout } = useAuth()
  const location = useLocation()

  const navItems = [
    { path: '/', label: 'Dashboard', icon: LayoutDashboard },
    { path: '/content', label: 'Content Moderation', icon: FileText },
    { path: '/flagged', label: 'Flagged Center', icon: Flag },
    { path: '/users', label: 'User Management', icon: Users },
    { path: '/analytics', label: 'Analytics', icon: BarChart3 },
    { path: '/settings', label: 'Settings', icon: Settings },
  ]

  return (
    <div style={{ display: 'flex', height: '100vh', backgroundColor: '#0f1419' }}>
      {/* Sidebar */}
      <aside
        style={{
          width: '240px',
          backgroundColor: '#1a1f2e',
          borderRight: '1px solid #2d3748',
          display: 'flex',
          flexDirection: 'column',
        }}
      >
        <div style={{ padding: '24px', borderBottom: '1px solid #2d3748' }}>
          <h1 style={{ color: '#78e08f', fontSize: '20px', fontWeight: 'bold' }}>
            NOIZE Admin
          </h1>
        </div>
        <nav style={{ flex: 1, padding: '16px 0' }}>
          {navItems.map((item) => {
            const Icon = item.icon
            const isActive = location.pathname === item.path
            return (
              <Link
                key={item.path}
                to={item.path}
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: '12px',
                  padding: '12px 24px',
                  color: isActive ? '#78e08f' : '#a0aec0',
                  backgroundColor: isActive ? '#2d3748' : 'transparent',
                  textDecoration: 'none',
                  borderLeft: isActive ? '3px solid #78e08f' : '3px solid transparent',
                }}
              >
                <Icon size={20} />
                <span>{item.label}</span>
              </Link>
            )
          })}
        </nav>
        <div style={{ padding: '16px', borderTop: '1px solid #2d3748' }}>
          <button
            onClick={logout}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '12px',
              width: '100%',
              padding: '12px',
              backgroundColor: 'transparent',
              border: '1px solid #2d3748',
              borderRadius: '8px',
              color: '#e53e3e',
              cursor: 'pointer',
            }}
          >
            <LogOut size={20} />
            <span>Logout</span>
          </button>
        </div>
      </aside>

      {/* Main Content */}
      <main style={{ flex: 1, overflow: 'auto', padding: '32px' }}>
        <Outlet />
      </main>
    </div>
  )
}
