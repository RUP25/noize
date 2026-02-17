import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../services/api'
import { Flag, Trash2, Search, MessageSquare, Bell, Ban } from 'lucide-react'
import { useState, useRef, useEffect } from 'react'

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

interface Message {
  id: string
  from: string
  from_id: string
  message: string
  type: string
  timestamp: string
  read: boolean
  data?: any
}

export default function ContentModeration() {
  const [searchQuery, setSearchQuery] = useState('')
  const [showMessageModal, setShowMessageModal] = useState(false)
  const [showMessageCenter, setShowMessageCenter] = useState(false)
  const [selectedChannel, setSelectedChannel] = useState<{ id: string; name: string } | null>(null)
  const [messageText, setMessageText] = useState('')
  const messageCenterRef = useRef<HTMLDivElement>(null)
  const queryClient = useQueryClient()

  // Close message center when clicking outside
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (messageCenterRef.current && !messageCenterRef.current.contains(event.target as Node)) {
        setShowMessageCenter(false)
      }
    }

    if (showMessageCenter) {
      document.addEventListener('mousedown', handleClickOutside)
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside)
    }
  }, [showMessageCenter])

  // Fetch all songs (or pending songs) for moderation - these can be suspended
  const { data: songs, isLoading, error } = useQuery<Song[]>({
    queryKey: ['songs', 'all', searchQuery],
    queryFn: async () => {
      const params: any = {}
      if (searchQuery.trim()) {
        params.search = searchQuery.trim()
      }
      // Fetch all songs - admins can suspend any song from here
      const response = await api.get('/admin/content/songs/all', { params })
      return response.data
    },
    retry: 2,
    retryDelay: 1000,
  })

  // Fetch messages for the notification center
  // TODO: Replace with actual API endpoint when message storage is implemented
  const { data: messages = [], isLoading: messagesLoading } = useQuery<Message[]>({
    queryKey: ['admin-messages'],
    queryFn: async () => {
      try {
        // Placeholder: This endpoint doesn't exist yet, but structure is ready
        // When implemented, it should return messages received by the admin
        // const response = await api.get('/admin/messages')
        // return response.data
        
        // For now, return empty array or mock data
        return []
      } catch (error) {
        console.error('Failed to fetch messages:', error)
        return []
      }
    },
    refetchInterval: 30000, // Refetch every 30 seconds
  })

  const unreadCount = messages.filter((msg) => !msg.read).length

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
      const response = await api.post('/admin/content/songs/moderate', {
        song_id: songId,
        action,
        reason,
      })
      return response.data
    },
    onSuccess: (data) => {
      console.log('Moderation successful:', data)
      queryClient.invalidateQueries({ queryKey: ['songs'] })
      queryClient.invalidateQueries({ queryKey: ['admin-stats'] })
      alert(`Song ${data.status === 'flagged' ? 'suspended' : data.status} successfully!`)
    },
    onError: (error: any) => {
      console.error('Moderation error:', error)
      const errorMessage = error?.response?.data?.detail || error?.message || 'Failed to moderate song'
      alert(`Error: ${errorMessage}`)
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

  const handleSuspend = (songId: number) => {
    if (confirm('Are you sure you want to suspend this song? It will be moved to the flagged center and listeners will see a suspension message.')) {
      moderateMutation.mutate({ songId, action: 'suspend' })
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
        // Send message to specific channel/user
        // user_id is a query parameter, notification is in the body
        await api.post(`/notifications/send?user_id=${selectedChannel.id}`, {
          type: 'admin_message',
          message: messageText,
          timestamp: new Date().toISOString(),
        })
      } else {
        // Broadcast to all channels (or handle general message)
        // For now, show a message that channel selection is needed
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
            Content Moderation
          </h1>
          <div style={{ display: 'flex', gap: '12px' }}>
            <div style={{ position: 'relative' }} ref={messageCenterRef}>
              <button
                onClick={() => setShowMessageCenter(!showMessageCenter)}
                style={{
                  padding: '8px 16px',
                  backgroundColor: '#4299e1',
                  color: '#fff',
                  border: 'none',
                  borderRadius: '8px',
                  cursor: 'pointer',
                  fontWeight: '600',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '6px',
                  position: 'relative',
                }}
              >
                <Bell size={16} />
                Messages
                {unreadCount > 0 && (
                  <span
                    style={{
                      position: 'absolute',
                      top: '-4px',
                      right: '-4px',
                      backgroundColor: '#f56565',
                      color: '#fff',
                      borderRadius: '50%',
                      width: '20px',
                      height: '20px',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      fontSize: '11px',
                      fontWeight: 'bold',
                    }}
                  >
                    {unreadCount > 99 ? '99+' : unreadCount}
                  </span>
                )}
              </button>

              {/* Message Center Dropdown */}
              {showMessageCenter && (
                <div
                  style={{
                    position: 'absolute',
                    top: '100%',
                    right: 0,
                    marginTop: '8px',
                    width: '400px',
                    maxHeight: '600px',
                    backgroundColor: '#1a1f2e',
                    border: '1px solid #2d3748',
                    borderRadius: '12px',
                    boxShadow: '0 4px 20px rgba(0, 0, 0, 0.5)',
                    zIndex: 1000,
                    display: 'flex',
                    flexDirection: 'column',
                  }}
                >
                  {/* Header */}
                  <div
                    style={{
                      padding: '16px',
                      borderBottom: '1px solid #2d3748',
                      display: 'flex',
                      justifyContent: 'space-between',
                      alignItems: 'center',
                    }}
                  >
                    <h3 style={{ color: '#e0e0e0', fontSize: '18px', fontWeight: 'bold', margin: 0 }}>
                      Message Center
                    </h3>
                    {unreadCount > 0 && (
                      <span
                        style={{
                          backgroundColor: '#f56565',
                          color: '#fff',
                          padding: '4px 8px',
                          borderRadius: '12px',
                          fontSize: '12px',
                          fontWeight: '600',
                        }}
                      >
                        {unreadCount} new
                      </span>
                    )}
                  </div>

                  {/* Messages List */}
                  <div
                    style={{
                      flex: 1,
                      overflowY: 'auto',
                      maxHeight: '500px',
                    }}
                  >
                    {messagesLoading ? (
                      <div style={{ padding: '40px', textAlign: 'center', color: '#a0aec0' }}>
                        Loading messages...
                      </div>
                    ) : messages.length === 0 ? (
                      <div style={{ padding: '40px', textAlign: 'center', color: '#a0aec0' }}>
                        <MessageSquare size={48} style={{ marginBottom: '12px', opacity: 0.5 }} />
                        <p style={{ margin: 0 }}>No messages yet</p>
                        <p style={{ margin: '8px 0 0 0', fontSize: '12px', color: '#718096' }}>
                          Messages you receive will appear here
                        </p>
                      </div>
                    ) : (
                      messages.map((message) => (
                        <div
                          key={message.id}
                          onClick={() => {
                            // Mark as read and potentially open message details
                            // TODO: Implement mark as read API call
                          }}
                          style={{
                            padding: '16px',
                            borderBottom: '1px solid #2d3748',
                            cursor: 'pointer',
                            backgroundColor: message.read ? 'transparent' : 'rgba(66, 153, 225, 0.1)',
                            transition: 'background-color 0.2s',
                          }}
                          onMouseEnter={(e) => {
                            e.currentTarget.style.backgroundColor = '#2d3748'
                          }}
                          onMouseLeave={(e) => {
                            e.currentTarget.style.backgroundColor = message.read ? 'transparent' : 'rgba(66, 153, 225, 0.1)'
                          }}
                        >
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '8px' }}>
                            <div style={{ flex: 1 }}>
                              <p style={{ color: '#e0e0e0', fontWeight: message.read ? 'normal' : 'bold', margin: '0 0 4px 0', fontSize: '14px' }}>
                                {message.from}
                              </p>
                              <p style={{ color: '#a0aec0', margin: 0, fontSize: '13px', lineHeight: '1.4' }}>
                                {message.message}
                              </p>
                            </div>
                            {!message.read && (
                              <span
                                style={{
                                  width: '8px',
                                  height: '8px',
                                  backgroundColor: '#4299e1',
                                  borderRadius: '50%',
                                  flexShrink: 0,
                                  marginLeft: '8px',
                                }}
                              />
                            )}
                          </div>
                          <p style={{ color: '#718096', fontSize: '11px', margin: '8px 0 0 0' }}>
                            {new Date(message.timestamp).toLocaleString()}
                          </p>
                        </div>
                      ))
                    )}
                  </div>

                  {/* Footer */}
                  <div
                    style={{
                      padding: '12px 16px',
                      borderTop: '1px solid #2d3748',
                      display: 'flex',
                      justifyContent: 'center',
                    }}
                  >
                    <button
                      onClick={() => {
                        setShowMessageCenter(false)
                        setShowMessageModal(true)
                        setSelectedChannel(null)
                      }}
                      style={{
                        padding: '8px 16px',
                        backgroundColor: '#4299e1',
                        color: '#fff',
                        border: 'none',
                        borderRadius: '8px',
                        cursor: 'pointer',
                        fontSize: '13px',
                        fontWeight: '600',
                      }}
                    >
                      Send New Message
                    </button>
                  </div>
                </div>
              )}
            </div>
          </div>
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
                  onClick={() => handleSuspend(song.id)}
                  disabled={moderateMutation.isPending || deleteMutation.isPending}
                  style={{
                    padding: '8px 16px',
                    backgroundColor: '#ed8936',
                    color: '#fff',
                    border: 'none',
                    borderRadius: '8px',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '6px',
                  }}
                >
                  <Ban size={16} />
                  Suspend
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
          No songs found
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
            {selectedChannel ? (
              <p style={{ color: '#a0aec0', fontSize: '14px', marginBottom: '16px' }}>
                Channel: {selectedChannel.name}
              </p>
            ) : (
              <p style={{ color: '#a0aec0', fontSize: '14px', marginBottom: '16px' }}>
                Select a channel from a song below to send a message, or use the Message button on a song card.
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
