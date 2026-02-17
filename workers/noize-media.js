
addEventListener('fetch', event => {
  event.respondWith(handle(event.request))
})

/**
 * Simplified worker that validates a bearer token by calling a backend introspect endpoint.
 * In production: verify JWT signature locally if you have the public key to avoid an external call.
 */
async function handle(request) {
  const url = new URL(request.url)
  // protect /media/stream/<key> routes
  if (url.pathname.startsWith('/media/stream/')) {
    const auth = request.headers.get('authorization') || ''
    if (!auth.startsWith('Bearer ')) return new Response('Unauthorized', { status: 401 })
    const token = auth.split(' ')[1]
    // call your backend to validate token (introspect)
    const resp = await fetch('https://api.yourdomain.com/auth/introspect', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ token })
    })
    if (!resp.ok) return new Response('Forbidden', { status: 403 })
    const body = await resp.json()
    if (!body.active) return new Response('Forbidden', { status: 403 })
    // generate signed URL or redirect to R2 public URL (this example redirects to R2 object URL)
    const key = url.pathname.replace('/media/stream/', '')
    // Construct R2 URL (replace with your account hash)
    const r2Url = `https://<account_hash>.r2.cloudflarestorage.com/${key}`
    return Response.redirect(r2Url, 302)
  }
  return fetch(request)
}
