import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { api } from '../services/api'
import { useState } from 'react'
import { Search, Ban, CheckCircle, Trash2, Check, X } from 'lucide-react'

interface User {
  id: string
  contact: string
  email: string | null
  channel_name: string | null
  full_name: string | null
  is_artist: boolean
  is_upgraded: boolean
  user_role: string
  kyc_verified: boolean
  is_suspended: boolean
  is_admin?: boolean
  created_at: string
}

export default function UserManagement() {
  const [search, setSearch] = useState('')
  const [roleFilter, setRoleFilter] = useState<string>('')
  const queryClient = useQueryClient()

  const { data: users, isLoading } = useQuery<User[]>({
    queryKey: ['users', search, roleFilter],
    queryFn: async () => {
      const params = new URLSearchParams()
      if (search) params.append('search', search)
      if (roleFilter) params.append('role', roleFilter)
      const response = await api.get(`/admin/users?${params.toString()}`)
      return response.data
    },
  })

  const manageMutation = useMutation({
    mutationFn: async ({
      userId,
      action,
      reason,
    }: {
      userId: string
      action: string
      reason?: string
    }) => {
      await api.post('/admin/users/manage', {
        user_id: userId,
        action,
        reason,
      })
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['users'] })
      queryClient.invalidateQueries({ queryKey: ['admin-stats'] })
    },
  })

  const handleAction = (userId: string, action: string) => {
    const actionNames: Record<string, string> = {
      suspend: 'suspend',
      activate: 'activate',
      approve: 'approve (activate)',
      reject: 'reject (permanently delete)',
      delete: 'permanently delete',
      promote_to_admin: 'promote to admin',
    }
    let confirmMessage = ''
    if (action === 'delete' || action === 'reject') {
      confirmMessage = 'Are you sure you want to permanently delete this user? This action cannot be undone.'
    } else if (action === 'approve') {
      confirmMessage = 'Are you sure you want to approve this user? They will be activated.'
    } else {
      confirmMessage = `Are you sure you want to ${actionNames[action]} this user?`
    }
    if (confirm(confirmMessage)) {
      // Map approve to activate, reject to delete
      const backendAction = action === 'approve' ? 'activate' : action === 'reject' ? 'delete' : action
      manageMutation.mutate({ userId, action: backendAction })
    }
  }

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
        User Management
      </h1>

      <div
        style={{
          display: 'flex',
          gap: '16px',
          marginBottom: '24px',
          flexWrap: 'wrap',
        }}
      >
        <div style={{ position: 'relative', flex: 1, minWidth: '200px' }}>
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
            placeholder="Search users..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            style={{
              width: '100%',
              padding: '12px 12px 12px 40px',
              backgroundColor: '#1a1f2e',
              border: '1px solid #2d3748',
              borderRadius: '8px',
              color: '#e0e0e0',
              fontSize: '14px',
            }}
          />
        </div>
        <select
          value={roleFilter}
          onChange={(e) => setRoleFilter(e.target.value)}
          style={{
            padding: '12px',
            backgroundColor: '#1a1f2e',
            border: '1px solid #2d3748',
            borderRadius: '8px',
            color: '#e0e0e0',
            fontSize: '14px',
            minWidth: '150px',
          }}
        >
          <option value="">All Roles</option>
          <option value="guest">Guest</option>
          <option value="listen">Listen</option>
          <option value="rep">REP</option>
          <option value="artist">Artist</option>
          <option value="influencer">Influencer</option>
        </select>
      </div>

      {isLoading ? (
        <div style={{ color: '#a0aec0', textAlign: 'center', padding: '40px' }}>
          Loading users...
        </div>
      ) : users && users.length > 0 ? (
        <div
          style={{
            backgroundColor: '#1a1f2e',
            border: '1px solid #2d3748',
            borderRadius: '12px',
            overflow: 'hidden',
          }}
        >
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid #2d3748' }}>
                <th style={{ padding: '16px', textAlign: 'left', color: '#a0aec0', fontSize: '14px' }}>
                  User
                </th>
                <th style={{ padding: '16px', textAlign: 'left', color: '#a0aec0', fontSize: '14px' }}>
                  Role
                </th>
                <th style={{ padding: '16px', textAlign: 'left', color: '#a0aec0', fontSize: '14px' }}>
                  Status
                </th>
                <th style={{ padding: '16px', textAlign: 'left', color: '#a0aec0', fontSize: '14px' }}>
                  Joined
                </th>
                <th style={{ padding: '16px', textAlign: 'right', color: '#a0aec0', fontSize: '14px' }}>
                  Actions
                </th>
              </tr>
            </thead>
            <tbody>
              {users.map((user) => (
                <tr
                  key={user.id}
                  style={{
                    borderBottom: '1px solid #2d3748',
                    backgroundColor: user.is_suspended ? '#2d1a1a' : 'transparent',
                  }}
                >
                  <td style={{ padding: '16px' }}>
                    <div>
                      <div style={{ color: '#e0e0e0', fontWeight: '600', marginBottom: '4px' }}>
                        {user.full_name || user.channel_name || user.email || user.contact}
                      </div>
                      <div style={{ color: '#a0aec0', fontSize: '12px' }}>
                        {user.email || user.contact}
                      </div>
                    </div>
                  </td>
                  <td style={{ padding: '16px', color: '#a0aec0' }}>
                    <span
                      style={{
                        display: 'inline-block',
                        padding: '4px 8px',
                        backgroundColor: '#2d3748',
                        borderRadius: '4px',
                        fontSize: '12px',
                      }}
                    >
                      {user.user_role}
                    </span>
                  </td>
                  <td style={{ padding: '16px' }}>
                    {user.is_suspended ? (
                      <span style={{ color: '#f56565' }}>Suspended</span>
                    ) : (
                      <span style={{ color: '#48bb78' }}>Active</span>
                    )}
                  </td>
                  <td style={{ padding: '16px', color: '#a0aec0', fontSize: '14px' }}>
                    {new Date(user.created_at).toLocaleDateString()}
                  </td>
                  <td style={{ padding: '16px', textAlign: 'right' }}>
                    <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
                      {user.is_suspended ? (
                        <>
                          <button
                            onClick={() => handleAction(user.id, 'approve')}
                            style={{
                              padding: '6px 12px',
                              backgroundColor: '#48bb78',
                              color: '#fff',
                              border: 'none',
                              borderRadius: '6px',
                              cursor: 'pointer',
                              display: 'flex',
                              alignItems: 'center',
                              gap: '4px',
                              fontSize: '12px',
                            }}
                          >
                            <Check size={14} />
                            Approve
                          </button>
                          <button
                            onClick={() => handleAction(user.id, 'reject')}
                            style={{
                              padding: '6px 12px',
                              backgroundColor: '#f56565',
                              color: '#fff',
                              border: 'none',
                              borderRadius: '6px',
                              cursor: 'pointer',
                              display: 'flex',
                              alignItems: 'center',
                              gap: '4px',
                              fontSize: '12px',
                            }}
                          >
                            <X size={14} />
                            Reject
                          </button>
                        </>
                      ) : (
                        <button
                          onClick={() => handleAction(user.id, 'suspend')}
                          style={{
                            padding: '6px 12px',
                            backgroundColor: '#ed8936',
                            color: '#fff',
                            border: 'none',
                            borderRadius: '6px',
                            cursor: 'pointer',
                            display: 'flex',
                            alignItems: 'center',
                            gap: '4px',
                            fontSize: '12px',
                          }}
                        >
                          <Ban size={14} />
                          Suspend
                        </button>
                      )}
                      <button
                        onClick={() => handleAction(user.id, 'delete')}
                        style={{
                          padding: '6px 12px',
                          backgroundColor: '#e53e3e',
                          color: '#fff',
                          border: 'none',
                          borderRadius: '6px',
                          cursor: 'pointer',
                          display: 'flex',
                          alignItems: 'center',
                          gap: '4px',
                          fontSize: '12px',
                        }}
                      >
                        <Trash2 size={14} />
                        Delete
                      </button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
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
          No users found
        </div>
      )}
    </div>
  )
}
