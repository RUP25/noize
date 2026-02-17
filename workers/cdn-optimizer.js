/**
 * Cloudflare Worker for CDN optimization and caching
 * Deploy this to Cloudflare Workers to optimize media delivery
 */

addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

async function handleRequest(request) {
  const url = new URL(request.url)
  
  // CORS headers
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Max-Age': '86400',
  }
  
  // Handle OPTIONS request
  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }
  
  // Only allow GET and HEAD
  if (request.method !== 'GET' && request.method !== 'HEAD') {
    return new Response('Method not allowed', { status: 405, headers: corsHeaders })
  }
  
  // Get the R2 key from path
  const key = url.pathname.replace(/^\//, '')
  
  if (!key || !key.startsWith('uploads/')) {
    return new Response('Invalid path', { status: 400, headers: corsHeaders })
  }
  
  // Get R2 bucket binding (configure in Workers dashboard)
  const bucket = env.R2_BUCKET
  
  if (!bucket) {
    return new Response('R2 bucket not configured', { status: 500, headers: corsHeaders })
  }
  
  try {
    // Get object from R2
    const object = await bucket.get(key)
    
    if (!object) {
      return new Response('Not found', { status: 404, headers: corsHeaders })
    }
    
    // Determine content type
    const contentType = object.httpMetadata?.contentType || 'application/octet-stream'
    
    // Image optimization using Cloudflare Image Resizing
    const isImage = contentType.startsWith('image/')
    const hasImageParams = url.searchParams.has('w') || url.searchParams.has('h') || url.searchParams.has('q')
    
    // If it's an image and has optimization params, use Cloudflare Image Resizing
    if (isImage && hasImageParams) {
      const width = url.searchParams.get('w')
      const height = url.searchParams.get('h')
      const quality = url.searchParams.get('q') || '85'
      
      // Build image resizing URL
      const imageUrl = new URL(request.url)
      imageUrl.searchParams.set('format', 'auto') // Auto format (WebP/AVIF when supported)
      
      // Redirect to Cloudflare Image Resizing
      return Response.redirect(imageUrl.toString(), 302)
    }
    
    // Set cache headers
    const headers = {
      ...corsHeaders,
      'Content-Type': contentType,
      'Cache-Control': isImage 
        ? 'public, max-age=31536000, immutable'  // 1 year for images
        : contentType.startsWith('audio/') || contentType.startsWith('video/')
        ? 'public, max-age=3600'  // 1 hour for media
        : 'public, max-age=86400',  // 1 day for other files
      'ETag': object.httpEtag,
      'Last-Modified': object.uploaded.toUTCString(),
      'X-Content-Type-Options': 'nosniff',
    }
    
    // Add content length if available
    if (object.size) {
      headers['Content-Length'] = object.size.toString()
    }
    
    // Handle range requests for audio/video streaming
    const range = request.headers.get('range')
    if (range && (contentType.startsWith('audio/') || contentType.startsWith('video/'))) {
      const [start, end] = parseRange(range, object.size)
      if (start !== null && end !== null) {
        const chunk = await object.range(start, end)
        return new Response(chunk.body, {
          status: 206,
          headers: {
            ...headers,
            'Content-Range': `bytes ${start}-${end}/${object.size}`,
            'Content-Length': (end - start + 1).toString(),
            'Accept-Ranges': 'bytes',
          }
        })
      }
    }
    
    // Return the object
    return new Response(object.body, { headers })
    
  } catch (error) {
    console.error('Error fetching from R2:', error)
    return new Response('Internal server error', { status: 500, headers: corsHeaders })
  }
}

function parseRange(range, size) {
  const match = range.match(/bytes=(\d+)-(\d*)/)
  if (!match) return [null, null]
  
  const start = parseInt(match[1], 10)
  const end = match[2] ? parseInt(match[2], 10) : size - 1
  
  if (start >= size || end >= size || start > end) {
    return [null, null]
  }
  
  return [start, end]
}
