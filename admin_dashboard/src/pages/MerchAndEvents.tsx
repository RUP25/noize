import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../services/api'
import { ShoppingBag, Plus, Edit, Trash2, ChevronLeft, ChevronRight, Calendar, MapPin, Clock, X } from 'lucide-react'

interface MerchItem {
  id: number
  title: string
  price: number
  image_url: string
  artist_id: string
  artist_name: string
  description?: string
  category?: string
  stock?: number
  purchase_link?: string
  created_at: string
}

interface Event {
  id: number
  title: string
  date: string
  time: string
  location: string
  artist_id: string
  artist_name: string
  description?: string
  ticket_price?: number
  created_at: string
}

interface CreateEventForm {
  title: string
  date: string
  time: string
  location: string
  description: string
  ticket_price: string
}

interface CreateMerchItemForm {
  title: string
  price: string
  description: string
  category: string
  stock: string
  purchase_link: string
  image_file?: File
  image_url?: string
}

export default function MerchAndEvents() {
  const [scrollPosition, setScrollPosition] = useState(0)
  const [selectedArtist, setSelectedArtist] = useState<string | null>(null)
  const [showCreateEvent, setShowCreateEvent] = useState(false)
  const [showCreateMerch, setShowCreateMerch] = useState(false)
  const [activeTab, setActiveTab] = useState<'merch' | 'events'>('merch')
  const [eventForm, setEventForm] = useState<CreateEventForm>({
    title: '',
    date: '',
    time: '',
    location: '',
    description: '',
    ticket_price: '',
  })
  const [merchForm, setMerchForm] = useState<CreateMerchItemForm>({
    title: '',
    price: '',
    description: '',
    category: '',
    stock: '',
    purchase_link: '',
    image_file: undefined,
    image_url: '',
  })
  const [imagePreview, setImagePreview] = useState<string | null>(null)
  
  // Validation errors
  const [merchErrors, setMerchErrors] = useState<Partial<Record<keyof CreateMerchItemForm, string>>>({})
  const [eventErrors, setEventErrors] = useState<Partial<Record<keyof CreateEventForm, string>>>({})

  const queryClient = useQueryClient()

  // Fetch merchandise from API
  const { data: merchItems = [], isLoading: isLoadingMerch } = useQuery<MerchItem[]>({
    queryKey: ['merch-items', selectedArtist],
    queryFn: async () => {
      try {
        const params: any = {}
        if (selectedArtist) {
          params.artist_id = selectedArtist
        }
        const response = await api.get('/admin/merchandise', { params })
        return response.data
      } catch (error) {
        console.error('Failed to fetch merchandise:', error)
        return []
      }
    },
  })

  // Fetch events from API
  const { data: events = [], isLoading: isLoadingEvents } = useQuery<Event[]>({
    queryKey: ['events', selectedArtist],
    queryFn: async () => {
      try {
        const params: any = {}
        if (selectedArtist) {
          params.artist_id = selectedArtist
        }
        const response = await api.get('/admin/events', { params })
        return response.data
      } catch (error) {
        console.error('Failed to fetch events:', error)
        return []
      }
    },
  })

  const createEventMutation = useMutation({
    mutationFn: async (eventData: CreateEventForm) => {
      const payload = {
        title: eventData.title,
        description: eventData.description || '',
        date: eventData.date,
        time: eventData.time,
        location: eventData.location,
        ticket_price: eventData.ticket_price ? parseFloat(eventData.ticket_price) : null,
      }
      const params: any = {}
      if (selectedArtist) {
        params.artist_id = selectedArtist
      }
      const response = await api.post('/admin/events', payload, { params })
      return response.data
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['events'] })
      setShowCreateEvent(false)
      setEventForm({
        title: '',
        date: '',
        time: '',
        location: '',
        description: '',
        ticket_price: '',
      })
      setEventErrors({})
      alert('Event created successfully!')
    },
  })

  const createMerchItemMutation = useMutation({
    mutationFn: async (merchData: CreateMerchItemForm) => {
      // TODO: Handle image upload separately if needed
      // For now, use image_url if provided
      const payload = {
        title: merchData.title,
        description: merchData.description || '',
        price: parseFloat(merchData.price) || 0,
        image_url: merchData.image_url || imagePreview || null,
        purchase_link: merchData.purchase_link || null,
        category: merchData.category || null,
        stock: merchData.stock ? parseInt(merchData.stock) : null,
      }
      const params: any = {}
      if (selectedArtist) {
        params.artist_id = selectedArtist
      }
      const response = await api.post('/admin/merchandise', payload, { params })
      return response.data
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['merch-items'] })
      setShowCreateMerch(false)
      setMerchForm({
        title: '',
        price: '',
        description: '',
        category: '',
        stock: '',
        purchase_link: '',
        image_file: undefined,
        image_url: '',
      })
      setImagePreview(null)
      setMerchErrors({})
      alert('Merchandise item created successfully!')
    },
  })

  // Validation functions
  const validateMerchForm = (): boolean => {
    const errors: Partial<Record<keyof CreateMerchItemForm, string>> = {}
    
    // Title validation
    if (!merchForm.title || !merchForm.title.trim()) {
      errors.title = 'Title is required'
    } else {
      const trimmed = merchForm.title.trim()
      if (trimmed.length < 1) {
        errors.title = 'Title must be at least 1 character'
      } else if (trimmed.length > 200) {
        errors.title = 'Title must be at most 200 characters'
      }
    }
    
    // Price validation
    if (!merchForm.price || !merchForm.price.trim()) {
      errors.price = 'Price is required'
    } else {
      const priceValue = parseFloat(merchForm.price)
      if (isNaN(priceValue)) {
        errors.price = 'Price must be a valid number'
      } else if (priceValue < 0) {
        errors.price = 'Price must be >= 0'
      } else if (priceValue > 1000000) {
        errors.price = 'Price must be <= 1,000,000'
      }
    }
    
    // Description validation
    if (merchForm.description && merchForm.description.length > 1000) {
      errors.description = 'Description must be at most 1000 characters'
    }
    
    // Purchase link validation
    if (merchForm.purchase_link && merchForm.purchase_link.trim()) {
      const urlPattern = /^https?:\/\/.+/
      if (!urlPattern.test(merchForm.purchase_link.trim())) {
        errors.purchase_link = 'Purchase link must be a valid URL starting with http:// or https://'
      }
    }
    
    // Category validation
    if (merchForm.category && merchForm.category.length > 50) {
      errors.category = 'Category must be at most 50 characters'
    }
    
    // Stock validation
    if (merchForm.stock && merchForm.stock.trim()) {
      const stockValue = parseInt(merchForm.stock)
      if (isNaN(stockValue)) {
        errors.stock = 'Stock must be a valid number'
      } else if (stockValue < 0) {
        errors.stock = 'Stock must be >= 0'
      }
    }
    
    setMerchErrors(errors)
    return Object.keys(errors).length === 0
  }

  const validateEventForm = (): boolean => {
    const errors: Partial<Record<keyof CreateEventForm, string>> = {}
    
    // Title validation
    if (!eventForm.title || !eventForm.title.trim()) {
      errors.title = 'Title is required'
    } else {
      const trimmed = eventForm.title.trim()
      if (trimmed.length < 1) {
        errors.title = 'Title must be at least 1 character'
      } else if (trimmed.length > 200) {
        errors.title = 'Title must be at most 200 characters'
      }
    }
    
    // Date validation
    if (!eventForm.date) {
      errors.date = 'Date is required'
    } else {
      const dateValue = new Date(eventForm.date)
      if (isNaN(dateValue.getTime())) {
        errors.date = 'Date must be a valid date'
      }
    }
    
    // Time validation
    if (!eventForm.time || !eventForm.time.trim()) {
      errors.time = 'Time is required'
    } else {
      const timePattern = /^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$/
      if (!timePattern.test(eventForm.time.trim())) {
        errors.time = 'Time must be in HH:MM format (24-hour, e.g., 14:30)'
      }
    }
    
    // Location validation
    if (!eventForm.location || !eventForm.location.trim()) {
      errors.location = 'Location is required'
    } else {
      const trimmed = eventForm.location.trim()
      if (trimmed.length < 1) {
        errors.location = 'Location must be at least 1 character'
      } else if (trimmed.length > 200) {
        errors.location = 'Location must be at most 200 characters'
      }
    }
    
    // Description validation
    if (eventForm.description && eventForm.description.length > 1000) {
      errors.description = 'Description must be at most 1000 characters'
    }
    
    // Ticket price validation
    if (eventForm.ticket_price && eventForm.ticket_price.trim()) {
      const priceValue = parseFloat(eventForm.ticket_price)
      if (isNaN(priceValue)) {
        errors.ticket_price = 'Ticket price must be a valid number'
      } else if (priceValue < 0) {
        errors.ticket_price = 'Ticket price must be >= 0'
      } else if (priceValue > 10000) {
        errors.ticket_price = 'Ticket price must be <= 10,000'
      }
    }
    
    setEventErrors(errors)
    return Object.keys(errors).length === 0
  }

  const handleImageChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0]
    if (file) {
      setMerchForm({ ...merchForm, image_file: file })
      const reader = new FileReader()
      reader.onloadend = () => {
        setImagePreview(reader.result as string)
      }
      reader.readAsDataURL(file)
    }
  }

  const handleCreateMerchItem = (e: React.FormEvent) => {
    e.preventDefault()
    if (!validateMerchForm()) {
      return
    }
    createMerchItemMutation.mutate(merchForm)
  }

  const handleCreateEvent = (e: React.FormEvent) => {
    e.preventDefault()
    if (!validateEventForm()) {
      return
    }
    createEventMutation.mutate(eventForm)
  }

  const scrollContainer = (direction: 'left' | 'right', containerId: string) => {
    const container = document.getElementById(containerId)
    if (!container) return

    const scrollAmount = 400
    const newPosition =
      direction === 'left'
        ? scrollPosition - scrollAmount
        : scrollPosition + scrollAmount

    container.scrollTo({
      left: Math.max(0, Math.min(newPosition, container.scrollWidth - container.clientWidth)),
      behavior: 'smooth',
    })
    setScrollPosition(newPosition)
  }

  return (
    <div>
      <div
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: '32px',
        }}
      >
        <h1
          style={{
            fontSize: '32px',
            fontWeight: 'bold',
            color: '#e0e0e0',
          }}
        >
          Merchandise & Events
        </h1>
        <div style={{ display: 'flex', gap: '12px' }}>
          {activeTab === 'events' && (
            <button
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                padding: '12px 24px',
                backgroundColor: '#78e08f',
                color: '#0f1419',
                border: 'none',
                borderRadius: '8px',
                cursor: 'pointer',
                fontWeight: '600',
              }}
              onClick={() => setShowCreateEvent(true)}
            >
              <Plus size={20} />
              Create Event
            </button>
          )}
          {activeTab === 'merch' && (
            <button
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                padding: '12px 24px',
                backgroundColor: '#78e08f',
                color: '#0f1419',
                border: 'none',
                borderRadius: '8px',
                cursor: 'pointer',
                fontWeight: '600',
              }}
              onClick={() => setShowCreateMerch(true)}
            >
              <Plus size={20} />
              Add Item
            </button>
          )}
        </div>
      </div>

      {/* Tabs */}
      <div
        style={{
          display: 'flex',
          gap: '8px',
          marginBottom: '24px',
          borderBottom: '1px solid #2d3748',
        }}
      >
        <button
          onClick={() => setActiveTab('merch')}
          style={{
            padding: '12px 24px',
            backgroundColor: 'transparent',
            border: 'none',
            borderBottom: activeTab === 'merch' ? '2px solid #78e08f' : '2px solid transparent',
            color: activeTab === 'merch' ? '#78e08f' : '#a0aec0',
            cursor: 'pointer',
            fontWeight: activeTab === 'merch' ? '600' : '400',
            fontSize: '16px',
          }}
        >
          Merchandise
        </button>
        <button
          onClick={() => setActiveTab('events')}
          style={{
            padding: '12px 24px',
            backgroundColor: 'transparent',
            border: 'none',
            borderBottom: activeTab === 'events' ? '2px solid #78e08f' : '2px solid transparent',
            color: activeTab === 'events' ? '#78e08f' : '#a0aec0',
            cursor: 'pointer',
            fontWeight: activeTab === 'events' ? '600' : '400',
            fontSize: '16px',
          }}
        >
          Events
        </button>
      </div>

      {/* Filter by Artist */}
      <div style={{ marginBottom: '24px' }}>
        <label
          style={{
            color: '#a0aec0',
            fontSize: '14px',
            marginRight: '12px',
          }}
        >
          Filter by Artist:
        </label>
        <select
          value={selectedArtist || ''}
          onChange={(e) => setSelectedArtist(e.target.value || null)}
          style={{
            padding: '8px 16px',
            backgroundColor: '#1a1f2e',
            border: '1px solid #2d3748',
            borderRadius: '6px',
            color: '#e0e0e0',
            cursor: 'pointer',
          }}
        >
          <option value="">All Artists</option>
          <option value="1">NOIZE</option>
        </select>
      </div>

      {/* Merchandise Tab */}
      {activeTab === 'merch' && (
        <div
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
              justifyContent: 'space-between',
              alignItems: 'center',
              marginBottom: '20px',
            }}
          >
            <h2
              style={{
                fontSize: '24px',
                fontWeight: '600',
                color: '#e0e0e0',
              }}
            >
              {selectedArtist ? `${merchItems[0]?.artist_name || 'Artist'} Merch` : 'All Merchandise'}
            </h2>
            <div style={{ display: 'flex', gap: '8px' }}>
              <button
                onClick={() => scrollContainer('left', 'merch-scroll-container')}
                style={{
                  padding: '8px',
                  backgroundColor: '#2d3748',
                  border: '1px solid #2d3748',
                  borderRadius: '6px',
                  color: '#e0e0e0',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                }}
              >
                <ChevronLeft size={20} />
              </button>
              <button
                onClick={() => scrollContainer('right', 'merch-scroll-container')}
                style={{
                  padding: '8px',
                  backgroundColor: '#2d3748',
                  border: '1px solid #2d3748',
                  borderRadius: '6px',
                  color: '#e0e0e0',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                }}
              >
                <ChevronRight size={20} />
              </button>
            </div>
          </div>

          {isLoadingMerch ? (
            <div style={{ color: '#a0aec0', textAlign: 'center', padding: '40px' }}>
              Loading merchandise...
            </div>
          ) : (
            <>
              <div
                id="merch-scroll-container"
                style={{
                  display: 'flex',
                  gap: '20px',
                  overflowX: 'auto',
                  overflowY: 'hidden',
                  paddingBottom: '10px',
                  scrollBehavior: 'smooth',
                  WebkitOverflowScrolling: 'touch',
                }}
                onScroll={(e) => {
                  const target = e.target as HTMLElement
                  setScrollPosition(target.scrollLeft)
                }}
              >
                {merchItems.map((item) => (
                  <div
                    key={item.id}
                    style={{
                      minWidth: '280px',
                      maxWidth: '280px',
                      backgroundColor: '#0f1419',
                      border: '1px solid #2d3748',
                      borderRadius: '12px',
                      overflow: 'hidden',
                      display: 'flex',
                      flexDirection: 'column',
                      transition: 'transform 0.2s, box-shadow 0.2s',
                      cursor: 'pointer',
                    }}
                    onMouseEnter={(e) => {
                      e.currentTarget.style.transform = 'translateY(-4px)'
                      e.currentTarget.style.boxShadow = '0 8px 16px rgba(120, 224, 143, 0.2)'
                    }}
                    onMouseLeave={(e) => {
                      e.currentTarget.style.transform = 'translateY(0)'
                      e.currentTarget.style.boxShadow = 'none'
                    }}
                  >
                    <div
                      style={{
                        width: '100%',
                        height: '280px',
                        backgroundColor: '#1a1f2e',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        position: 'relative',
                      }}
                    >
                      <img
                        src={item.image_url}
                        alt={item.title}
                        style={{
                          width: '100%',
                          height: '100%',
                          objectFit: 'cover',
                        }}
                        onError={(e) => {
                          const target = e.target as HTMLImageElement
                          target.style.display = 'none'
                        }}
                      />
                      {item.stock !== undefined && (
                        <div
                          style={{
                            position: 'absolute',
                            top: '8px',
                            right: '8px',
                            padding: '4px 8px',
                            backgroundColor: item.stock > 10 ? '#78e08f' : '#f56565',
                            color: '#0f1419',
                            borderRadius: '4px',
                            fontSize: '12px',
                            fontWeight: '600',
                          }}
                        >
                          {item.stock > 10 ? 'In Stock' : `Only ${item.stock} left`}
                        </div>
                      )}
                    </div>
                    <div style={{ padding: '16px', flex: 1, display: 'flex', flexDirection: 'column' }}>
                      <h3
                        style={{
                          fontSize: '16px',
                          fontWeight: '600',
                          color: '#e0e0e0',
                          marginBottom: '8px',
                          lineHeight: '1.4',
                          display: '-webkit-box',
                          WebkitLineClamp: 2,
                          WebkitBoxOrient: 'vertical',
                          overflow: 'hidden',
                        }}
                      >
                        {item.title}
                      </h3>
                      {item.description && (
                        <p
                          style={{
                            fontSize: '12px',
                            color: '#a0aec0',
                            marginBottom: '12px',
                            lineHeight: '1.4',
                            display: '-webkit-box',
                            WebkitLineClamp: 2,
                            WebkitBoxOrient: 'vertical',
                            overflow: 'hidden',
                          }}
                        >
                          {item.description}
                        </p>
                      )}
                      <div style={{ marginTop: 'auto', display: 'flex', flexDirection: 'column', gap: '12px' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                          <span
                            style={{
                              fontSize: '20px',
                              fontWeight: 'bold',
                              color: '#78e08f',
                            }}
                          >
                            ${item.price.toFixed(2)}
                          </span>
                          <div style={{ display: 'flex', gap: '8px' }}>
                            <button
                              onClick={(e) => {
                                e.stopPropagation()
                                alert(`Edit item: ${item.title}`)
                              }}
                              style={{
                                padding: '6px',
                                backgroundColor: '#2d3748',
                                border: '1px solid #2d3748',
                                borderRadius: '4px',
                                color: '#78e08f',
                                cursor: 'pointer',
                                display: 'flex',
                                alignItems: 'center',
                              }}
                              title="Edit"
                            >
                              <Edit size={16} />
                            </button>
                            <button
                              onClick={(e) => {
                                e.stopPropagation()
                                if (confirm(`Delete "${item.title}"?`)) {
                                  alert('Delete functionality coming soon')
                                }
                              }}
                              style={{
                                padding: '6px',
                                backgroundColor: '#2d3748',
                                border: '1px solid #2d3748',
                                borderRadius: '4px',
                                color: '#f56565',
                                cursor: 'pointer',
                                display: 'flex',
                                alignItems: 'center',
                              }}
                              title="Delete"
                            >
                              <Trash2 size={16} />
                            </button>
                          </div>
                        </div>
                        {item.purchase_link && (
                          <a
                            href={item.purchase_link}
                            target="_blank"
                            rel="noopener noreferrer"
                            onClick={(e) => e.stopPropagation()}
                            style={{
                              width: '100%',
                              padding: '10px',
                              backgroundColor: '#78e08f',
                              color: '#0f1419',
                              textAlign: 'center',
                              borderRadius: '6px',
                              textDecoration: 'none',
                              fontWeight: '600',
                              fontSize: '14px',
                              display: 'block',
                            }}
                          >
                            Buy on Amazon →
                          </a>
                        )}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
              {merchItems.length === 0 && (
                <div
                  style={{
                    textAlign: 'center',
                    padding: '60px 20px',
                    color: '#a0aec0',
                  }}
                >
                  <ShoppingBag size={64} color="#4a5568" style={{ marginBottom: '16px', opacity: 0.5 }} />
                  <p style={{ fontSize: '18px', marginBottom: '8px' }}>No merchandise items found</p>
                  <p style={{ fontSize: '14px', color: '#718096' }}>Add your first item to get started</p>
                </div>
              )}
            </>
          )}
        </div>
      )}

      {/* Events Tab */}
      {activeTab === 'events' && (
        <div
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
              justifyContent: 'space-between',
              alignItems: 'center',
              marginBottom: '20px',
            }}
          >
            <h2
              style={{
                fontSize: '24px',
                fontWeight: '600',
                color: '#e0e0e0',
              }}
            >
              Live Show Events
            </h2>
          </div>

          {isLoadingEvents ? (
            <div style={{ color: '#a0aec0', textAlign: 'center', padding: '40px' }}>
              Loading events...
            </div>
          ) : (
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))',
                gap: '20px',
              }}
            >
              {events.map((event) => (
                <div
                  key={event.id}
                  style={{
                    backgroundColor: '#0f1419',
                    border: '1px solid #2d3748',
                    borderRadius: '12px',
                    padding: '20px',
                    transition: 'transform 0.2s, box-shadow 0.2s',
                    cursor: 'pointer',
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.transform = 'translateY(-4px)'
                    e.currentTarget.style.boxShadow = '0 8px 16px rgba(120, 224, 143, 0.2)'
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.transform = 'translateY(0)'
                    e.currentTarget.style.boxShadow = 'none'
                  }}
                >
                  <h3
                    style={{
                      fontSize: '18px',
                      fontWeight: '600',
                      color: '#e0e0e0',
                      marginBottom: '12px',
                    }}
                  >
                    {event.title}
                  </h3>
                  {event.description && (
                    <p
                      style={{
                        fontSize: '14px',
                        color: '#a0aec0',
                        marginBottom: '16px',
                        lineHeight: '1.5',
                      }}
                    >
                      {event.description}
                    </p>
                  )}
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', marginBottom: '16px' }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#e0e0e0' }}>
                      <Calendar size={16} color="#78e08f" />
                      <span style={{ fontSize: '14px' }}>
                        {new Date(event.date).toLocaleDateString('en-US', {
                          weekday: 'long',
                          year: 'numeric',
                          month: 'long',
                          day: 'numeric',
                        })}
                      </span>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#e0e0e0' }}>
                      <Clock size={16} color="#78e08f" />
                      <span style={{ fontSize: '14px' }}>{event.time}</span>
                    </div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#e0e0e0' }}>
                      <MapPin size={16} color="#78e08f" />
                      <span style={{ fontSize: '14px' }}>{event.location}</span>
                    </div>
                  </div>
                  {event.ticket_price && (
                    <div
                      style={{
                        display: 'flex',
                        justifyContent: 'space-between',
                        alignItems: 'center',
                        paddingTop: '16px',
                        borderTop: '1px solid #2d3748',
                      }}
                    >
                      <span
                        style={{
                          fontSize: '20px',
                          fontWeight: 'bold',
                          color: '#78e08f',
                        }}
                      >
                        ${event.ticket_price.toFixed(2)}
                      </span>
                      <div style={{ display: 'flex', gap: '8px' }}>
                        <button
                          onClick={(e) => {
                            e.stopPropagation()
                            alert(`Edit event: ${event.title}`)
                          }}
                          style={{
                            padding: '6px',
                            backgroundColor: '#2d3748',
                            border: '1px solid #2d3748',
                            borderRadius: '4px',
                            color: '#78e08f',
                            cursor: 'pointer',
                            display: 'flex',
                            alignItems: 'center',
                          }}
                          title="Edit"
                        >
                          <Edit size={16} />
                        </button>
                        <button
                          onClick={(e) => {
                            e.stopPropagation()
                            if (confirm(`Delete "${event.title}"?`)) {
                              alert('Delete functionality coming soon')
                            }
                          }}
                          style={{
                            padding: '6px',
                            backgroundColor: '#2d3748',
                            border: '1px solid #2d3748',
                            borderRadius: '4px',
                            color: '#f56565',
                            cursor: 'pointer',
                            display: 'flex',
                            alignItems: 'center',
                          }}
                          title="Delete"
                        >
                          <Trash2 size={16} />
                        </button>
                      </div>
                    </div>
                  )}
                </div>
              ))}
              {events.length === 0 && (
                <div
                  style={{
                    gridColumn: '1 / -1',
                    textAlign: 'center',
                    padding: '60px 20px',
                    color: '#a0aec0',
                  }}
                >
                  <Calendar size={64} color="#4a5568" style={{ marginBottom: '16px', opacity: 0.5 }} />
                  <p style={{ fontSize: '18px', marginBottom: '8px' }}>No events found</p>
                  <p style={{ fontSize: '14px', color: '#718096' }}>Create your first live show event</p>
                </div>
              )}
            </div>
          )}
        </div>
      )}

      {/* Create Event Modal */}
      {showCreateEvent && (
        <div
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
          }}
          onClick={() => setShowCreateEvent(false)}
        >
          <div
            style={{
              backgroundColor: '#1a1f2e',
              border: '1px solid #2d3748',
              borderRadius: '12px',
              padding: '32px',
              width: '90%',
              maxWidth: '500px',
              maxHeight: '90vh',
              overflowY: 'auto',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                marginBottom: '24px',
              }}
            >
              <h2
                style={{
                  fontSize: '24px',
                  fontWeight: '600',
                  color: '#e0e0e0',
                }}
              >
                Create Live Show Event
              </h2>
              <button
                onClick={() => setShowCreateEvent(false)}
                style={{
                  padding: '8px',
                  backgroundColor: 'transparent',
                  border: 'none',
                  color: '#a0aec0',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                }}
              >
                <X size={24} />
              </button>
            </div>

            <form onSubmit={handleCreateEvent}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                <div>
                  <label
                    style={{
                      display: 'block',
                      color: '#e0e0e0',
                      fontSize: '14px',
                      fontWeight: '500',
                      marginBottom: '8px',
                    }}
                  >
                    Event Title *
                  </label>
                  <input
                    type="text"
                    value={eventForm.title}
                    onChange={(e) => {
                      setEventForm({ ...eventForm, title: e.target.value })
                      if (eventErrors.title) {
                        setEventErrors({ ...eventErrors, title: undefined })
                      }
                    }}
                    placeholder="e.g., NOIZE Live Concert (1-200 characters)"
                    maxLength={200}
                    required
                    style={{
                      width: '100%',
                      padding: '12px',
                      backgroundColor: '#0f1419',
                      border: `1px solid ${eventErrors.title ? '#f56565' : '#2d3748'}`,
                      borderRadius: '8px',
                      color: '#e0e0e0',
                      fontSize: '14px',
                    }}
                  />
                  {eventErrors.title && (
                    <p style={{ color: '#f56565', fontSize: '12px', marginTop: '4px', marginBottom: 0 }}>
                      {eventErrors.title}
                    </p>
                  )}
                  <p style={{ color: '#a0aec0', fontSize: '12px', marginTop: '4px', marginBottom: 0 }}>
                    {eventForm.title.length}/200 characters
                  </p>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                  <div>
                    <label
                      style={{
                        display: 'block',
                        color: '#e0e0e0',
                        fontSize: '14px',
                        fontWeight: '500',
                        marginBottom: '8px',
                      }}
                    >
                      Date *
                    </label>
                    <input
                      type="date"
                      value={eventForm.date}
                      onChange={(e) => {
                        setEventForm({ ...eventForm, date: e.target.value })
                        if (eventErrors.date) {
                          setEventErrors({ ...eventErrors, date: undefined })
                        }
                      }}
                      required
                      style={{
                        width: '100%',
                        padding: '12px',
                        backgroundColor: '#0f1419',
                        border: `1px solid ${eventErrors.date ? '#f56565' : '#2d3748'}`,
                        borderRadius: '8px',
                        color: '#e0e0e0',
                        fontSize: '14px',
                      }}
                    />
                    {eventErrors.date && (
                      <p style={{ color: '#f56565', fontSize: '12px', marginTop: '4px', marginBottom: 0 }}>
                        {eventErrors.date}
                      </p>
                    )}
                  </div>

                  <div>
                    <label
                      style={{
                        display: 'block',
                        color: '#e0e0e0',
                        fontSize: '14px',
                        fontWeight: '500',
                        marginBottom: '8px',
                      }}
                    >
                      Time *
                    </label>
                    <input
                      type="time"
                      value={eventForm.time}
                      onChange={(e) => {
                        setEventForm({ ...eventForm, time: e.target.value })
                        if (eventErrors.time) {
                          setEventErrors({ ...eventErrors, time: undefined })
                        }
                      }}
                      required
                      style={{
                        width: '100%',
                        padding: '12px',
                        backgroundColor: '#0f1419',
                        border: `1px solid ${eventErrors.time ? '#f56565' : '#2d3748'}`,
                        borderRadius: '8px',
                        color: '#e0e0e0',
                        fontSize: '14px',
                      }}
                    />
                    {eventErrors.time && (
                      <p style={{ color: '#f56565', fontSize: '12px', marginTop: '4px', marginBottom: 0 }}>
                        {eventErrors.time}
                      </p>
                    )}
                  </div>
                </div>

                <div>
                  <label
                    style={{
                      display: 'block',
                      color: '#e0e0e0',
                      fontSize: '14px',
                      fontWeight: '500',
                      marginBottom: '8px',
                    }}
                  >
                    Location *
                  </label>
                  <input
                    type="text"
                    value={eventForm.location}
                    onChange={(e) => {
                      setEventForm({ ...eventForm, location: e.target.value })
                      if (eventErrors.location) {
                        setEventErrors({ ...eventErrors, location: undefined })
                      }
                    }}
                    placeholder="e.g., Madison Square Garden, New York (1-200 characters)"
                    maxLength={200}
                    required
                    style={{
                      width: '100%',
                      padding: '12px',
                      backgroundColor: '#0f1419',
                      border: `1px solid ${eventErrors.location ? '#f56565' : '#2d3748'}`,
                      borderRadius: '8px',
                      color: '#e0e0e0',
                      fontSize: '14px',
                    }}
                  />
                  {eventErrors.location && (
                    <p style={{ color: '#f56565', fontSize: '12px', marginTop: '4px', marginBottom: 0 }}>
                      {eventErrors.location}
                    </p>
                  )}
                  <p style={{ color: '#a0aec0', fontSize: '12px', marginTop: '4px', marginBottom: 0 }}>
                    {eventForm.location.length}/200 characters
                  </p>
                </div>

                <div>
                  <label
                    style={{
                      display: 'block',
                      color: '#e0e0e0',
                      fontSize: '14px',
                      fontWeight: '500',
                      marginBottom: '8px',
                    }}
                  >
                    Description
                  </label>
                  <textarea
                    value={eventForm.description}
                    onChange={(e) => {
                      setEventForm({ ...eventForm, description: e.target.value })
                      if (eventErrors.description) {
                        setEventErrors({ ...eventErrors, description: undefined })
                      }
                    }}
                    placeholder="Event description..."
                    rows={4}
                    maxLength={1000}
                    style={{
                      width: '100%',
                      padding: '12px',
                      backgroundColor: '#0f1419',
                      border: `1px solid ${eventErrors.description ? '#f56565' : '#2d3748'}`,
                      borderRadius: '8px',
                      color: '#e0e0e0',
                      fontSize: '14px',
                      resize: 'vertical',
                      fontFamily: 'inherit',
                    }}
                  />
                  {eventErrors.description && (
                    <p style={{ color: '#f56565', fontSize: '12px', marginTop: '4px', marginBottom: 0 }}>
                      {eventErrors.description}
                    </p>
                  )}
                  <p style={{ color: '#a0aec0', fontSize: '12px', marginTop: '4px', marginBottom: 0 }}>
                    {eventForm.description.length}/1000 characters
                  </p>
                </div>

                <div>
                  <label
                    style={{
                      display: 'block',
                      color: '#e0e0e0',
                      fontSize: '14px',
                      fontWeight: '500',
                      marginBottom: '8px',
                    }}
                  >
                    Ticket Price ($)
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    max="10000"
                    value={eventForm.ticket_price}
                    onChange={(e) => {
                      setEventForm({ ...eventForm, ticket_price: e.target.value })
                      if (eventErrors.ticket_price) {
                        setEventErrors({ ...eventErrors, ticket_price: undefined })
                      }
                    }}
                    placeholder="0.00"
                    style={{
                      width: '100%',
                      padding: '12px',
                      backgroundColor: '#0f1419',
                      border: `1px solid ${eventErrors.ticket_price ? '#f56565' : '#2d3748'}`,
                      borderRadius: '8px',
                      color: '#e0e0e0',
                      fontSize: '14px',
                    }}
                  />
                  {eventErrors.ticket_price && (
                    <p style={{ color: '#f56565', fontSize: '12px', marginTop: '4px', marginBottom: 0 }}>
                      {eventErrors.ticket_price}
                    </p>
                  )}
                </div>

                <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end', marginTop: '8px' }}>
                  <button
                    type="button"
                    onClick={() => setShowCreateEvent(false)}
                    style={{
                      padding: '12px 24px',
                      backgroundColor: '#2d3748',
                      border: '1px solid #2d3748',
                      borderRadius: '8px',
                      color: '#e0e0e0',
                      cursor: 'pointer',
                      fontWeight: '600',
                    }}
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={createEventMutation.isPending}
                    style={{
                      padding: '12px 24px',
                      backgroundColor: '#78e08f',
                      border: 'none',
                      borderRadius: '8px',
                      color: '#0f1419',
                      cursor: createEventMutation.isPending ? 'not-allowed' : 'pointer',
                      fontWeight: '600',
                      opacity: createEventMutation.isPending ? 0.6 : 1,
                    }}
                  >
                    {createEventMutation.isPending ? 'Creating...' : 'Create Event'}
                  </button>
                </div>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Create Merchandise Item Modal */}
      {showCreateMerch && (
        <div
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
          }}
          onClick={() => setShowCreateMerch(false)}
        >
          <div
            style={{
              backgroundColor: '#1a1f2e',
              border: '1px solid #2d3748',
              borderRadius: '12px',
              padding: '32px',
              width: '90%',
              maxWidth: '600px',
              maxHeight: '90vh',
              overflowY: 'auto',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div
              style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                marginBottom: '24px',
              }}
            >
              <h2
                style={{
                  fontSize: '24px',
                  fontWeight: '600',
                  color: '#e0e0e0',
                }}
              >
                Add Merchandise Item
              </h2>
              <button
                onClick={() => setShowCreateMerch(false)}
                style={{
                  padding: '8px',
                  backgroundColor: 'transparent',
                  border: 'none',
                  color: '#a0aec0',
                  cursor: 'pointer',
                  display: 'flex',
                  alignItems: 'center',
                }}
              >
                <X size={24} />
              </button>
            </div>

            <form onSubmit={handleCreateMerchItem}>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                {/* Image Upload */}
                <div>
                  <label
                    style={{
                      display: 'block',
                      color: '#e0e0e0',
                      fontSize: '14px',
                      fontWeight: '500',
                      marginBottom: '8px',
                    }}
                  >
                    Item Photo
                  </label>
                  <div
                    style={{
                      display: 'flex',
                      flexDirection: 'column',
                      gap: '12px',
                    }}
                  >
                    {imagePreview ? (
                      <div
                        style={{
                          position: 'relative',
                          width: '100%',
                          maxWidth: '300px',
                          margin: '0 auto',
                        }}
                      >
                        <img
                          src={imagePreview}
                          alt="Preview"
                          style={{
                            width: '100%',
                            height: '300px',
                            objectFit: 'cover',
                            borderRadius: '8px',
                            border: '1px solid #2d3748',
                          }}
                        />
                        <button
                          type="button"
                          onClick={() => {
                            setImagePreview(null)
                            setMerchForm({ ...merchForm, image_file: undefined })
                          }}
                          style={{
                            position: 'absolute',
                            top: '8px',
                            right: '8px',
                            padding: '6px',
                            backgroundColor: '#f56565',
                            border: 'none',
                            borderRadius: '4px',
                            color: '#fff',
                            cursor: 'pointer',
                          }}
                        >
                          <X size={16} />
                        </button>
                      </div>
                    ) : (
                      <label
                        style={{
                          display: 'flex',
                          flexDirection: 'column',
                          alignItems: 'center',
                          justifyContent: 'center',
                          padding: '40px',
                          border: '2px dashed #2d3748',
                          borderRadius: '8px',
                          cursor: 'pointer',
                          backgroundColor: '#0f1419',
                          transition: 'border-color 0.2s',
                        }}
                        onMouseEnter={(e) => {
                          e.currentTarget.style.borderColor = '#78e08f'
                        }}
                        onMouseLeave={(e) => {
                          e.currentTarget.style.borderColor = '#2d3748'
                        }}
                      >
                        <input
                          type="file"
                          accept="image/*"
                          onChange={handleImageChange}
                          style={{ display: 'none' }}
                        />
                        <div style={{ textAlign: 'center' }}>
                          <div
                            style={{
                              fontSize: '48px',
                              marginBottom: '12px',
                              color: '#78e08f',
                            }}
                          >
                            📷
                          </div>
                          <span style={{ color: '#e0e0e0', fontSize: '14px' }}>
                            Click to upload image
                          </span>
                          <span style={{ color: '#a0aec0', fontSize: '12px', display: 'block', marginTop: '4px' }}>
                            PNG, JPG up to 10MB
                          </span>
                        </div>
                      </label>
                    )}
                  </div>
                </div>

                <div>
                  <label
                    style={{
                      display: 'block',
                      color: '#e0e0e0',
                      fontSize: '14px',
                      fontWeight: '500',
                      marginBottom: '8px',
                    }}
                  >
                    Item Title *
                  </label>
                  <input
                    type="text"
                    value={merchForm.title}
                    onChange={(e) => {
                      setMerchForm({ ...merchForm, title: e.target.value })
                      // Clear error when user starts typing
                      if (merchErrors.title) {
                        setMerchErrors({ ...merchErrors, title: undefined })
                      }
                    }}
                    placeholder="e.g., Official NOIZE T-Shirt (1-200 characters)"
                    maxLength={200}
                    required
                    style={{
                      width: '100%',
                      padding: '12px',
                      backgroundColor: '#0f1419',
                      border: `1px solid ${merchErrors.title ? '#f56565' : '#2d3748'}`,
                      borderRadius: '8px',
                      color: '#e0e0e0',
                      fontSize: '14px',
                    }}
                  />
                  {merchErrors.title && (
                    <p style={{ color: '#f56565', fontSize: '12px', marginTop: '4px', marginBottom: 0 }}>
                      {merchErrors.title}
                    </p>
                  )}
                  <p style={{ color: '#a0aec0', fontSize: '12px', marginTop: '4px', marginBottom: 0 }}>
                    {merchForm.title.length}/200 characters
                  </p>
                </div>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                  <div>
                    <label
                      style={{
                        display: 'block',
                        color: '#e0e0e0',
                        fontSize: '14px',
                        fontWeight: '500',
                        marginBottom: '8px',
                      }}
                    >
                      Price ($) *
                    </label>
                    <input
                      type="number"
                      step="0.01"
                      min="0"
                      max="1000000"
                      value={merchForm.price}
                      onChange={(e) => {
                        setMerchForm({ ...merchForm, price: e.target.value })
                        if (merchErrors.price) {
                          setMerchErrors({ ...merchErrors, price: undefined })
                        }
                      }}
                      placeholder="0.00"
                      required
                      style={{
                        width: '100%',
                        padding: '12px',
                        backgroundColor: '#0f1419',
                        border: `1px solid ${merchErrors.price ? '#f56565' : '#2d3748'}`,
                        borderRadius: '8px',
                        color: '#e0e0e0',
                        fontSize: '14px',
                      }}
                    />
                    {merchErrors.price && (
                      <p style={{ color: '#f56565', fontSize: '12px', marginTop: '4px', marginBottom: 0 }}>
                        {merchErrors.price}
                      </p>
                    )}
                  </div>

                  <div>
                    <label
                      style={{
                        display: 'block',
                        color: '#e0e0e0',
                        fontSize: '14px',
                        fontWeight: '500',
                        marginBottom: '8px',
                      }}
                    >
                      Category
                    </label>
                    <select
                      value={merchForm.category}
                      onChange={(e) => {
                        setMerchForm({ ...merchForm, category: e.target.value })
                        if (merchErrors.category) {
                          setMerchErrors({ ...merchErrors, category: undefined })
                        }
                      }}
                      style={{
                        width: '100%',
                        padding: '12px',
                        backgroundColor: '#0f1419',
                        border: `1px solid ${merchErrors.category ? '#f56565' : '#2d3748'}`,
                        borderRadius: '8px',
                        color: '#e0e0e0',
                        fontSize: '14px',
                        cursor: 'pointer',
                      }}
                    >
                      <option value="">Select category</option>
                      <option value="Apparel">Apparel</option>
                      <option value="Accessories">Accessories</option>
                      <option value="Music">Music</option>
                      <option value="Other">Other</option>
                    </select>
                    {merchErrors.category && (
                      <p style={{ color: '#f56565', fontSize: '12px', marginTop: '4px', marginBottom: 0 }}>
                        {merchErrors.category}
                      </p>
                    )}
                  </div>
                </div>

                <div>
                  <label
                    style={{
                      display: 'block',
                      color: '#e0e0e0',
                      fontSize: '14px',
                      fontWeight: '500',
                      marginBottom: '8px',
                    }}
                  >
                    Purchase Link (Amazon, etc.) *
                  </label>
                  <input
                    type="url"
                    value={merchForm.purchase_link}
                    onChange={(e) => {
                      setMerchForm({ ...merchForm, purchase_link: e.target.value })
                      if (merchErrors.purchase_link) {
                        setMerchErrors({ ...merchErrors, purchase_link: undefined })
                      }
                    }}
                    placeholder="https://amazon.com/..."
                    required
                    style={{
                      width: '100%',
                      padding: '12px',
                      backgroundColor: '#0f1419',
                      border: `1px solid ${merchErrors.purchase_link ? '#f56565' : '#2d3748'}`,
                      borderRadius: '8px',
                      color: '#e0e0e0',
                      fontSize: '14px',
                    }}
                  />
                  {merchErrors.purchase_link && (
                    <p style={{ color: '#f56565', fontSize: '12px', marginTop: '4px', marginBottom: 0 }}>
                      {merchErrors.purchase_link}
                    </p>
                  )}
                  <p style={{ color: '#a0aec0', fontSize: '12px', marginTop: '4px' }}>
                    Link where fans can purchase this item
                  </p>
                </div>

                <div>
                  <label
                    style={{
                      display: 'block',
                      color: '#e0e0e0',
                      fontSize: '14px',
                      fontWeight: '500',
                      marginBottom: '8px',
                    }}
                  >
                    Description
                  </label>
                  <textarea
                    value={merchForm.description}
                    onChange={(e) => {
                      setMerchForm({ ...merchForm, description: e.target.value })
                      if (merchErrors.description) {
                        setMerchErrors({ ...merchErrors, description: undefined })
                      }
                    }}
                    placeholder="Item description..."
                    rows={4}
                    maxLength={1000}
                    style={{
                      width: '100%',
                      padding: '12px',
                      backgroundColor: '#0f1419',
                      border: `1px solid ${merchErrors.description ? '#f56565' : '#2d3748'}`,
                      borderRadius: '8px',
                      color: '#e0e0e0',
                      fontSize: '14px',
                      resize: 'vertical',
                      fontFamily: 'inherit',
                    }}
                  />
                  {merchErrors.description && (
                    <p style={{ color: '#f56565', fontSize: '12px', marginTop: '4px', marginBottom: 0 }}>
                      {merchErrors.description}
                    </p>
                  )}
                  <p style={{ color: '#a0aec0', fontSize: '12px', marginTop: '4px', marginBottom: 0 }}>
                    {merchForm.description.length}/1000 characters
                  </p>
                </div>

                <div>
                  <label
                    style={{
                      display: 'block',
                      color: '#e0e0e0',
                      fontSize: '14px',
                      fontWeight: '500',
                      marginBottom: '8px',
                    }}
                  >
                    Stock Quantity
                  </label>
                  <input
                    type="number"
                    min="0"
                    value={merchForm.stock}
                    onChange={(e) => {
                      setMerchForm({ ...merchForm, stock: e.target.value })
                      if (merchErrors.stock) {
                        setMerchErrors({ ...merchErrors, stock: undefined })
                      }
                    }}
                    placeholder="0"
                    style={{
                      width: '100%',
                      padding: '12px',
                      backgroundColor: '#0f1419',
                      border: `1px solid ${merchErrors.stock ? '#f56565' : '#2d3748'}`,
                      borderRadius: '8px',
                      color: '#e0e0e0',
                      fontSize: '14px',
                    }}
                  />
                  {merchErrors.stock && (
                    <p style={{ color: '#f56565', fontSize: '12px', marginTop: '4px', marginBottom: 0 }}>
                      {merchErrors.stock}
                    </p>
                  )}
                </div>

                <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end', marginTop: '8px' }}>
                  <button
                    type="button"
                    onClick={() => {
                      setShowCreateMerch(false)
                      setImagePreview(null)
                    }}
                    style={{
                      padding: '12px 24px',
                      backgroundColor: '#2d3748',
                      border: '1px solid #2d3748',
                      borderRadius: '8px',
                      color: '#e0e0e0',
                      cursor: 'pointer',
                      fontWeight: '600',
                    }}
                  >
                    Cancel
                  </button>
                  <button
                    type="submit"
                    disabled={createMerchItemMutation.isPending}
                    style={{
                      padding: '12px 24px',
                      backgroundColor: '#78e08f',
                      border: 'none',
                      borderRadius: '8px',
                      color: '#0f1419',
                      cursor: createMerchItemMutation.isPending ? 'not-allowed' : 'pointer',
                      fontWeight: '600',
                      opacity: createMerchItemMutation.isPending ? 0.6 : 1,
                    }}
                  >
                    {createMerchItemMutation.isPending ? 'Creating...' : 'Add Item'}
                  </button>
                </div>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
