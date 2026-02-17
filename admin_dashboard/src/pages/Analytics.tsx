import { useQuery } from '@tanstack/react-query'
import { api } from '../services/api'
import {
  LineChart,
  Line,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts'

export default function Analytics() {
  const { data: uploadTrends } = useQuery({
    queryKey: ['upload-trends'],
    queryFn: async () => {
      const response = await api.get('/admin/analytics/upload-trends?days=30')
      return response.data
    },
  })

  const { data: userGrowth } = useQuery({
    queryKey: ['user-growth'],
    queryFn: async () => {
      const response = await api.get('/admin/analytics/user-growth?days=30')
      return response.data
    },
  })

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
        Analytics
      </h1>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '32px' }}>
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
              marginBottom: '24px',
            }}
          >
            Song Upload Trends (Last 30 Days)
          </h2>
          <ResponsiveContainer width="100%" height={300}>
            <LineChart data={uploadTrends || []}>
              <CartesianGrid strokeDasharray="3 3" stroke="#2d3748" />
              <XAxis dataKey="date" stroke="#a0aec0" />
              <YAxis stroke="#a0aec0" />
              <Tooltip
                contentStyle={{
                  backgroundColor: '#1a1f2e',
                  border: '1px solid #2d3748',
                  borderRadius: '8px',
                }}
              />
              <Legend />
              <Line
                type="monotone"
                dataKey="count"
                stroke="#78e08f"
                strokeWidth={2}
                name="Uploads"
              />
            </LineChart>
          </ResponsiveContainer>
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
              marginBottom: '24px',
            }}
          >
            User Growth (Last 30 Days)
          </h2>
          <ResponsiveContainer width="100%" height={300}>
            <BarChart data={userGrowth || []}>
              <CartesianGrid strokeDasharray="3 3" stroke="#2d3748" />
              <XAxis dataKey="date" stroke="#a0aec0" />
              <YAxis stroke="#a0aec0" />
              <Tooltip
                contentStyle={{
                  backgroundColor: '#1a1f2e',
                  border: '1px solid #2d3748',
                  borderRadius: '8px',
                }}
              />
              <Legend />
              <Bar dataKey="count" fill="#4299e1" name="New Users" />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  )
}
