import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../services/api'
import { Flag, Trash2, Search, MessageSquare, Check, X } from 'lucide-react'
import { useState } from 'react'

interface Song {
  id: number
  title: string
  album: string | null
  artist: string
  artist_id: string
  cover_photo_url: string | null
  created_at: string
  moderation_status: string | null
  like_count?: number
}

export default function FlaggedCenter() {
  const [searchQuery, setSearchQuery] = useState('')
  const [showMessageModal, setShowMessageModal] = useState(false)
  const [selectedChannel, setSelectedChannel] = useState<{ id: string; name: string } | null>(null)
  const [messageText, setMessageText] = useState('')
  const queryClient = useQueryClient()

  // Fetch only flagged/suspended songs
  const { data: songs, isLoading, error } = useQuery<Song[]>({
    queryKey: ['songs', 'flagged', searchQuery],
    queryFn: async () => {
      const params: any = { status: 'flagged' }
      if (searchQuery.trim()) {
        params.search = searchQuery.trim()
      }
      const response = await api.get('/admin/content/songs/all', { params })
      return response.data
    },
    retry: 2,
    retryDelay: 1000,
  })

  const moderateMutation = useMutation({
    mutationFn: async ({
      songId,
      action,
      reason,
    }: {
      songId: number
      action: string
      reason?: string
    }) => {
      await api.post('/admin/content/songs/moderate', {
        song_id: songId,
        action,
        reason,
      })
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['songs'] })
      queryClient.invalidateQueries({ queryKey: ['admin-stats'] })
    },
  })

  const deleteMutation = useMutation({
    mutationFn: async (songId: number) => {
      await api.delete(`/admin/content/songs/${songId}`)
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['songs'] })
      queryClient.invalidateQueries({ queryKey: ['admin-stats'] })
    },
  })

  const handleApprove = (songId: number) => {
    if (confirm('Are you sure you want to approve this song? It will go back live.')) {
      moderateMutation.mutate({ songId, action: 'approve' })
    }
  }

  const handleReject = (songId: number) => {
    if (confirm('Are you sure you want to reject this song? It will be permanently deleted. This action cannot be undone.')) {
      deleteMutation.mutate(songId)
    }
  }

  const handleDelete = (songId: number) => {
    if (confirm('Are you sure you want to permanently delete this song? This action cannot be undone.')) {
      deleteMutation.mutate(songId)
    }
  }

  const handleMessageChannel = (artistId: string, artistName: string) => {
    setSelectedChannel({ id: artistId, name: artistName })
    setShowMessageModal(true)
  }

  const handleSendMessage = async () => {
    if (!messageText.trim()) return
    
    try {
      if (selectedChannel) {
        await api.post(`/notifications/send?user_id=${selectedChannel.id}`, {
          type: 'admin_message',
          message: messageText,
          timestamp: new Date().toISOString(),
        })
      } else {
        alert('Please select a channel from a song to send a message.')
        return
      }
      alert('Message sent successfully!')
      setShowMessageModal(false)
      setMessageText('')
      setSelectedChannel(null)
    } catch (error) {
      console.error('Failed to send message:', error)
      alert('Failed to send message. Please try again.')
    }
  }

  return (
    <div>
      <div
        style={{
          display: 'flex',
          flexDirection: 'column',
          gap: '20px',
          marginBottom: '32px',
        }}
      >
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
          }}
        >
          <h1
            style={{
              fontSize: '32px',
              fontWeight: 'bold',
              color: '#e0e0e0',
            }}
          >
            Flagged Center
          </h1>
        </div>
        <div
          style={{
            position: 'relative',
            maxWidth: '500px',
          }}
        >
          <Search
            size={20}
            style={{
              position: 'absolute',
              left: '12px',
              top: '50%',
              transform: 'translateY(-50%)',
              color: '#a0aec0',
            }}
          />
          <input
            type="text"
            placeholder="Search by title, album, or artist..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            style={{
              width: '100%',
              padding: '12px 16px 12px 40px',
              backgroundColor: '#1a1f2e',
              border: '1px solid #2d3748',
              borderRadius: '8px',
              color: '#e0e0e0',
              fontSize: '14px',
              outline: 'none',
            }}
            onKeyDown={(e) => {
              if (e.key === 'Enter') {
                e.preventDefault()
              }
            }}
          />
        </div>
      </div>

      {error ? (
        <div
          style={{
            backgroundColor: '#1a1f2e',
            border: '1px solid #f56565',
            borderRadius: '12px',
            padding: '40px',
            textAlign: 'center',
            color: '#f56565',
          }}
        >
          <p style={{ marginBottom: '8px', fontWeight: 'bold' }}>Failed to load songs</p>
          <p style={{ fontSize: '14px', color: '#a0aec0' }}>
            {error instanceof Error ? error.message : 'An error occurred while loading songs'}
          </p>
          <p style={{ fontSize: '12px', color: '#718096', marginTop: '16px' }}>
            Make sure the backend server is running at http://localhost:8000
          </p>
        </div>
      ) : isLoading ? (
        <div style={{ color: '#a0aec0', textAlign: 'center', padding: '40px' }}>
          <p>Loading songs...</p>
        </div>
      ) : songs && songs.length > 0 ? (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
          {songs.map((song) => (
            <div
              key={song.id}
              style={{
                backgroundColor: '#1a1f2e',
                border: '1px solid #2d3748',
                borderRadius: '12px',
                padding: '20px',
                display: 'flex',
                gap: '20px',
              }}
            >
              {song.cover_photo_url && (
                <img
                  src={song.cover_photo_url}
                  alt={song.title}
                  style={{
                    width: '80px',
                    height: '80px',
                    borderRadius: '8px',
                    objectFit: 'cover',
                  }}
                />
              )}
              <div style={{ flex: 1 }}>
                <h3 style={{ color: '#e0e0e0', fontSize: '18px', marginBottom: '4px' }}>
                  {song.title}
                </h3>
                <p style={{ color: '#a0aec0', fontSize: '14px', marginBottom: '4px' }}>
                  {song.album || 'No album'}
                </p>
                <p style={{ color: '#78e08f', fontSize: '14px', marginBottom: '8px' }}>
                  Artist: {song.artist}
                </p>
                <p style={{ color: '#a0aec0', fontSize: '12px' }}>
                  Uploaded: {new Date(song.created_at).toLocaleDateString()}
                </p>
                {song.moderation_status && (
                  <span
                    style={{
                      display: 'inline-block',
                      padding: '4px 8px',
                      backgroundColor: '#2d3748',
                      color: '#a0aec0',
                      borderRadius: '4px',
                      fontSize: '12px',
                      marginTop: '8px',
                    }}
                  >
                    Status: {song.moderation_status}
                  </span>
                )}
              </div>
              <div style={{ display: 'flex', gap: '8px', alignItems: 'flex-start', flexWrap: 'wrap' }}>
                <button
                  onClick={() => handleMessageChannel(song.artist_id, song.artist)}
                  style={{
                    padding: '8px 16px',
                    backgroundColor: '#4299e1',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '8px',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                  }}
                >
                  <MessageSquare size={16} />
                  Message
                </button>
                <button
                  onClick={() => handleApprove(song.id)}
                  disabled={moderateMutation.isPending || deleteMutation.isPending}
                  style={{
                    padding: '8px 16px',
                    backgroundColor: '#48bb78',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '8px',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                  }}
                >
                  <Check size={16} />
                  Approve
                </button>
                <button
                  onClick={() => handleReject(song.id)}
                  disabled={moderateMutation.isPending || deleteMutation.isPending}
                  style={{
                    padding: '8px 16px',
                    backgroundColor: '#f56565',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '8px',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                  }}
                >
                  <X size={16} />
                  Reject
                </button>
                <button
                  onClick={() => handleDelete(song.id)}
                  disabled={moderateMutation.isPending || deleteMutation.isPending}
                  style={{
                    padding: '8px 16px',
                    backgroundColor: '#e53e3e',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '8px',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                  }}
                >
                  <Trash2 size={16} />
                  Delete
                </button>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div
          style={{
            backgroundColor: '#1a1f2e',
            border: '1px solid #2d3748',
            borderRadius: '12px',
            padding: '40px',
            textAlign: 'center',
            color: '#a0aec0',
          }}
        >
          <Flag size={48} style={{ marginBottom: '16px', opacity: 0.5 }} />
          <p style={{ margin: 0, fontSize: '18px', marginBottom: '8px' }}>No flagged songs</p>
          <p style={{ margin: 0, fontSize: '14px', color: '#718096' }}>
            Suspended songs will appear here
          </p>
        </div>
      )}

      {/* Message Modal */}
      {showMessageModal && (
        <div
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            backgroundColor: 'rgba(0, 0, 0, 0.7)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
          }}
          onClick={() => {
            setShowMessageModal(false)
            setMessageText('')
            setSelectedChannel(null)
          }}
        >
          <div
            style={{
              backgroundColor: '#1a1f2e',
              border: '1px solid #2d3748',
              borderRadius: '12px',
              padding: '24px',
              width: '90%',
              maxWidth: '500px',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <h2 style={{ color: '#e0e0e0', marginBottom: '16px', fontSize: '20px' }}>
              {selectedChannel ? `Message ${selectedChannel.name}` : 'Send Message'}
            </h2>
            {selectedChannel && (
              <p style={{ color: '#a0aec0', fontSize: '14px', marginBottom: '16px' }}>
                Channel: {selectedChannel.name}
              </p>
            )}
            <textarea
              value={messageText}
              onChange={(e) => setMessageText(e.target.value)}
              placeholder="Enter your message..."
              style={{
                width: '100%',
                minHeight: '120px',
                padding: '12px',
                backgroundColor: '#0f1419',
                border: '1px solid #2d3748',
                borderRadius: '8px',
                color: '#e0e0e0',
                fontSize: '14px',
                outline: 'none',
                resize: 'vertical',
                marginBottom: '16px',
              }}
            />
            <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end' }}>
              <button
                onClick={() => {
                  setShowMessageModal(false)
                  setMessageText('')
                  setSelectedChannel(null)
                }}
                style={{
                  padding: '8px 16px',
                  backgroundColor: '#2d3748',
                  color: '#e0e0e0',
                  border: 'none',
                  borderRadius: '8px',
                  cursor: 'pointer',
                  fontWeight: '600',
                }}
              >
                Cancel
              </button>
              <button
                onClick={handleSendMessage}
                disabled={!messageText.trim() || !selectedChannel}
                style={{
                  padding: '8px 16px',
                  backgroundColor: messageText.trim() && selectedChannel ? '#4299e1' : '#2d3748',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '8px',
                  cursor: messageText.trim() && selectedChannel ? 'pointer' : 'not-allowed',
                  fontWeight: '600',
                  opacity: messageText.trim() && selectedChannel ? 1 : 0.5,
                }}
              >
                Send
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
