import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../services/api'
import { useEffect, useState } from 'react'
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

  const { data: uiConfig } = useQuery<{
    story_title: string
    greetings: Record<string, string>
  }>({
    queryKey: ['uiConfig'],
    queryFn: async () => {
      const response = await api.get('/config/ui')
      return response.data
    },
  })

  const [localFeatures, setLocalFeatures] = useState<Record<string, boolean>>(
    features || {}
  )

  const [storyTitle, setStoryTitle] = useState<string>('Your Story')
  const [greetings, setGreetings] = useState<Record<string, string>>({
    morning: 'Good morning',
    afternoon: 'Good afternoon',
    evening: 'Good evening',
    night: 'Good night',
  })

  const toggleMutation = useMutation({
    mutationFn: async (toggle: FeatureToggle) => {
      await api.post('/admin/features/toggle', toggle)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['features'] })
    },
  })

  const uiConfigMutation = useMutation({
    mutationFn: async (payload: { story_title: string; greetings: Record<string, string> }) => {
      await api.put('/config/ui', payload)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['uiConfig'] })
    },
  })

  const handleToggle = (featureName: string, enabled: boolean) => {
    setLocalFeatures((prev) => ({ ...prev, [featureName]: enabled }))
    toggleMutation.mutate({ feature_name: featureName, enabled })
  }

  // Keep local UI config in sync once loaded
  useEffect(() => {
    if (!uiConfig) return
    setStoryTitle(uiConfig.story_title || 'Your Story')
    setGreetings({
      morning: uiConfig.greetings?.morning ?? 'Good morning',
      afternoon: uiConfig.greetings?.afternoon ?? 'Good afternoon',
      evening: uiConfig.greetings?.evening ?? 'Good evening',
      night: uiConfig.greetings?.night ?? 'Good night',
    })
  }, [uiConfig])

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
          marginBottom: '24px',
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
          App Greeting (Listener Home)
        </h2>

        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <label style={{ color: '#a0aec0', fontSize: '12px' }}>Section title</label>
          <input
            value={storyTitle}
            onChange={(e) => setStoryTitle(e.target.value)}
            style={{
              padding: '10px 12px',
              borderRadius: '8px',
              border: '1px solid #2d3748',
              backgroundColor: '#0f1419',
              color: '#e0e0e0',
            }}
          />

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
            {(['morning', 'afternoon', 'evening', 'night'] as const).map((k) => (
              <div key={k} style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <label style={{ color: '#a0aec0', fontSize: '12px' }}>
                  {k.charAt(0).toUpperCase() + k.slice(1)}
                </label>
                <input
                  value={greetings[k] || ''}
                  onChange={(e) => setGreetings((prev) => ({ ...prev, [k]: e.target.value }))}
                  style={{
                    padding: '10px 12px',
                    borderRadius: '8px',
                    border: '1px solid #2d3748',
                    backgroundColor: '#0f1419',
                    color: '#e0e0e0',
                  }}
                />
              </div>
            ))}
          </div>

          <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
            <button
              onClick={() => uiConfigMutation.mutate({ story_title: storyTitle, greetings })}
              style={{
                display: 'inline-flex',
                alignItems: 'center',
                gap: '8px',
                padding: '10px 14px',
                borderRadius: '10px',
                border: '1px solid #2d3748',
                backgroundColor: '#0f1419',
                color: '#78e08f',
                cursor: 'pointer',
              }}
            >
              <Save size={16} />
              Save greeting
            </button>
          </div>
        </div>
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
