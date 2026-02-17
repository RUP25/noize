import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../services/api'
import { useState } from 'react'
import { Save } from 'lucide-react'

interface FeatureToggle {
  feature_name: string
  enabled: boolean
}

export default function Settings() {
  const queryClient = useQueryClient()
  const { data: features } = useQuery<Record<string, boolean>>({
    queryKey: ['features'],
    queryFn: async () => {
      const response = await api.get('/admin/features')
      return response.data
    },
  })

  const [localFeatures, setLocalFeatures] = useState<Record<string, boolean>>(
    features || {}
  )

  const toggleMutation = useMutation({
    mutationFn: async (toggle: FeatureToggle) => {
      await api.post('/admin/features/toggle', toggle)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['features'] })
    },
  })

  const handleToggle = (featureName: string, enabled: boolean) => {
    setLocalFeatures((prev) => ({ ...prev, [featureName]: enabled }))
    toggleMutation.mutate({ feature_name: featureName, enabled })
  }

  if (!features) {
    return <div style={{ color: '#a0aec0' }}>Loading settings...</div>
  }

  const featureList = [
    { key: 'new_user_registration', label: 'New User Registration' },
    { key: 'song_uploads', label: 'Song Uploads' },
    { key: 'playlist_sharing', label: 'Playlist Sharing' },
    { key: 'donation_features', label: 'Donation Features' },
    { key: 'rep_program', label: 'REP Program' },
    { key: 'kyc_verification', label: 'KYC Verification' },
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
        Settings
      </h1>

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
          Feature Toggles
        </h2>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          {featureList.map((feature) => (
            <div
              key={feature.key}
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                padding: '16px',
                backgroundColor: '#0f1419',
                borderRadius: '8px',
                border: '1px solid #2d3748',
              }}
            >
              <div>
                <div style={{ color: '#e0e0e0', fontWeight: '500', marginBottom: '4px' }}>
                  {feature.label}
                </div>
                <div style={{ color: '#a0aec0', fontSize: '12px' }}>
                  {localFeatures[feature.key] ? 'Enabled' : 'Disabled'}
                </div>
              </div>
              <label
                style={{
                  position: 'relative',
                  display: 'inline-block',
                  width: '48px',
                  height: '24px',
                }}
              >
                <input
                  type="checkbox"
                  checked={localFeatures[feature.key] || false}
                  onChange={(e) => handleToggle(feature.key, e.target.checked)}
                  style={{ opacity: 0, width: 0, height: 0 }}
                />
                <span
                  style={{
                    position: 'absolute',
                    cursor: 'pointer',
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    backgroundColor: localFeatures[feature.key]
                      ? '#78e08f'
                      : '#2d3748',
                    borderRadius: '24px',
                    transition: '0.3s',
                  }}
                >
                  <span
                    style={{
                      position: 'absolute',
                      content: '""',
                      height: '18px',
                      width: '18px',
                      left: '3px',
                      bottom: '3px',
                      backgroundColor: '#fff',
                      borderRadius: '50%',
                      transition: '0.3s',
                      transform: localFeatures[feature.key]
                        ? 'translateX(24px)'
                        : 'translateX(0)',
                    }}
                  />
                </span>
              </label>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
