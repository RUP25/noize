import { useQuery } from '@tanstack/react-query'
import { api } from '../services/api'
import { Users, Music, ListMusic, Clock, TrendingUp, AlertCircle } from 'lucide-react'

interface AdminStats {
  total_users: number
  total_artists: number
  total_songs: number
  total_playlists: number
  pending_songs: number
  active_users_30d: number
  new_users_7d: number
}

export default function Dashboard() {
  const { data: stats, isLoading } = useQuery<AdminStats>({
    queryKey: ['admin-stats'],
    queryFn: async () => {
      const response = await api.get('/admin/stats')
      return response.data
    },
  })

  if (isLoading) {
    return <div style={{ color: '#a0aec0' }}>Loading dashboard...</div>
  }

  const statCards = [
    {
      label: 'Total Users',
      value: stats?.total_users || 0,
      icon: Users,
      color: '#4299e1',
    },
    {
      label: 'Artists',
      value: stats?.total_artists || 0,
      icon: Music,
      color: '#48bb78',
    },
    {
      label: 'Total Songs',
      value: stats?.total_songs || 0,
      icon: Music,
      color: '#ed8936',
    },
    {
      label: 'Playlists',
      value: stats?.total_playlists || 0,
      icon: ListMusic,
      color: '#9f7aea',
    },
    {
      label: 'Pending Moderation',
      value: stats?.pending_songs || 0,
      icon: AlertCircle,
      color: '#f56565',
    },
    {
      label: 'Active Users (30d)',
      value: stats?.active_users_30d || 0,
      icon: TrendingUp,
      color: '#38b2ac',
    },
    {
      label: 'New Users (7d)',
      value: stats?.new_users_7d || 0,
      icon: Clock,
      color: '#78e08f',
    },
  ]

  return (
    <div>
      <h1
        style={{
          fontSize: '32px',
          fontWeight: 'bold',
          color: '#e0e0e0',
          marginBottom: '32px',
        }}
      >
        Dashboard
      </h1>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fill, minmax(240px, 1fr))',
          gap: '20px',
          marginBottom: '32px',
        }}
      >
        {statCards.map((card) => {
          const Icon = card.icon
          return (
            <div
              key={card.label}
              style={{
                backgroundColor: '#1a1f2e',
                border: '1px solid #2d3748',
                borderRadius: '12px',
                padding: '24px',
              }}
            >
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  marginBottom: '12px',
                }}
              >
                <Icon size={24} color={card.color} />
                <span
                  style={{
                    fontSize: '32px',
                    fontWeight: 'bold',
                    color: '#e0e0e0',
                  }}
                >
                  {card.value.toLocaleString()}
                </span>
              </div>
              <p style={{ color: '#a0aec0', fontSize: '14px' }}>{card.label}</p>
            </div>
          )
        })}
      </div>

      <div
        style={{
          backgroundColor: '#1a1f2e',
          border: '1px solid #2d3748',
          borderRadius: '12px',
          padding: '24px',
        }}
      >
        <h2
          style={{
            fontSize: '20px',
            fontWeight: '600',
            color: '#e0e0e0',
            marginBottom: '16px',
          }}
        >
          Quick Actions
        </h2>
        <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
          <a
            href="/content"
            style={{
              padding: '12px 24px',
              backgroundColor: '#78e08f',
              color: '#0f1419',
              borderRadius: '8px',
              textDecoration: 'none',
              fontWeight: '600',
            }}
          >
            Review Pending Content
          </a>
          <a
            href="/users"
            style={{
              padding: '12px 24px',
              backgroundColor: '#4299e1',
              color: '#fff',
              borderRadius: '8px',
              textDecoration: 'none',
              fontWeight: '600',
            }}
          >
            Manage Users
          </a>
          <a
            href="/analytics"
            style={{
              padding: '12px 24px',
              backgroundColor: '#9f7aea',
              color: '#fff',
              borderRadius: '8px',
              textDecoration: 'none',
              fontWeight: '600',
            }}
          >
            View Analytics
          </a>
        </div>
      </div>
    </div>
  )
}
