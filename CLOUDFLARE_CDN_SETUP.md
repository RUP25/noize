# Cloudflare CDN Setup Guide for Production

This guide explains how to set up Cloudflare CDN for better content distribution using your existing Cloudflare R2 storage.

## 🎯 Why Use Cloudflare CDN?

1. **Global Distribution** - Content served from 300+ data centers worldwide
2. **Faster Load Times** - Reduced latency for users globally
3. **Image Optimization** - Automatic WebP/AVIF conversion and resizing
4. **Cost Effective** - Free CDN with R2 Custom Domains
5. **DDoS Protection** - Built-in security and protection
6. **Bandwidth Savings** - Reduced load on your backend

## 📋 Prerequisites

1. Cloudflare account with R2 bucket already set up
2. ~~Domain name~~ **NOT REQUIRED for mobile apps!** Use free `your-bucket.r2.dev` domain
3. R2 bucket with public access enabled

> **Note for Mobile Apps**: You don't need a custom domain! Cloudflare provides a free `your-bucket.r2.dev` domain that works perfectly for mobile apps. Custom domains are only needed if you want branded URLs for web apps.

## 🚀 Setup Steps

### Step 1: Enable R2 Custom Domain (or use free .r2.dev domain)

**For Mobile Apps (Recommended - No Domain Needed):**

1. **Go to Cloudflare Dashboard**
   - Navigate to: R2 → Your Bucket → Settings → Custom Domain

2. **Use Free R2 Domain**
   - Click "Connect Domain"
   - Cloudflare will automatically assign: `your-bucket.r2.dev`
   - **No DNS setup needed!** Works immediately
   - This is perfect for mobile apps - no domain required!

**For Web Apps (Optional - Custom Domain):**

If you want branded URLs for web:
- Enter your custom domain (e.g., `cdn.yourdomain.com`)
- Cloudflare will create DNS records automatically
- Wait for DNS propagation (usually 1-5 minutes)

> **Mobile App Recommendation**: Use the free `your-bucket.r2.dev` domain. It's free, works immediately, and provides the same CDN benefits!

### Step 2: Configure Environment Variables

Add CDN configuration to your `backend/.env` file:

```env
# Existing R2 configuration
R2_ENDPOINT=https://<your-account-id>.r2.cloudflarestorage.com
R2_ACCESS_KEY=<your-access-key>
R2_SECRET_KEY=<your-secret-key>
R2_BUCKET=noize-dev

# CDN Configuration
CDN_ENABLED=true

# For Mobile Apps (Recommended - No domain needed):
CDN_DOMAIN=your-bucket.r2.dev  # Replace 'your-bucket' with your actual bucket name

# For Web Apps (Optional - Custom domain):
# CDN_DOMAIN=cdn.yourdomain.com

# Optional: Fallback R2 public domain
R2_PUBLIC_DOMAIN=your-bucket.r2.dev

# CDN Settings
CDN_CACHE_TTL=31536000  # 1 year for images
CDN_USE_HTTPS=true
CDN_IMAGE_OPTIMIZATION=true
CDN_IMAGE_QUALITY=85
```

### Step 3: Deploy Cloudflare Worker (Optional but Recommended)

The Cloudflare Worker provides advanced optimization and caching.

1. **Install Wrangler CLI**
   ```bash
   npm install -g wrangler
   ```

2. **Login to Cloudflare**
   ```bash
   wrangler login
   ```

3. **Configure Worker**
   Create `wrangler.toml` in the `workers/` directory:
   ```toml
   name = "cdn-optimizer"
   main = "cdn-optimizer.js"
   compatibility_date = "2024-01-01"

   [[r2_buckets]]
   binding = "R2_BUCKET"
   bucket_name = "noize-dev"
   ```

4. **Deploy Worker**
   ```bash
   cd workers
   wrangler deploy
   ```

5. **Connect Worker to Custom Domain**
   - Go to Workers & Pages → cdn-optimizer → Settings → Triggers
   - Add Custom Domain: `cdn.yourdomain.com`

### Step 4: Update Backend Configuration

The backend code is already updated to use CDN. Just restart:

```bash
docker-compose restart backend
```

### Step 5: Test CDN

1. **Test CDN URL Generation**
   ```bash
   curl http://localhost:8000/media/cdn/uploads/test/image.jpg
   ```

2. **Test Image Optimization**
   ```bash
   # Original image
   curl http://localhost:8000/media/public/uploads/test/image.jpg
   
   # Optimized (300px width)
   curl "http://localhost:8000/media/public/uploads/test/image.jpg?redirect=true&width=300"
   ```

3. **Verify CDN Headers**
   ```bash
   curl -I https://cdn.yourdomain.com/uploads/test/image.jpg
   # Should see: CF-Cache-Status: HIT
   ```

## 🔧 Configuration Options

### CDN Domain Options

**Option 1: Custom Domain (Recommended)**
```env
CDN_DOMAIN=cdn.yourdomain.com
```
- Professional URL
- Full control
- Requires domain setup

**Option 2: R2 Custom Domain (Easiest)**
```env
CDN_DOMAIN=your-bucket.r2.dev
```
- No domain needed
- Free
- Automatic setup

**Option 3: Disable CDN (Development)**
```env
CDN_ENABLED=false
```
- Uses direct R2 URLs
- No CDN benefits
- Good for local testing

### Image Optimization

Cloudflare automatically optimizes images when using query parameters:

```
# Resize to 300px width
https://cdn.yourdomain.com/image.jpg?w=300

# Resize to 300x200
https://cdn.yourdomain.com/image.jpg?w=300&h=200

# Resize with quality
https://cdn.yourdomain.com/image.jpg?w=300&q=80

# Auto format (WebP/AVIF when supported)
https://cdn.yourdomain.com/image.jpg?w=300&format=auto
```

### Cache Settings

```env
# Long cache for images (1 year)
CDN_CACHE_TTL=31536000

# Medium cache for media (1 hour)
# Set in code: 3600 seconds

# Short cache for dynamic content (1 day)
# Set in code: 86400 seconds
```

## 📊 API Endpoints

### Get CDN URL
```http
GET /media/cdn/{key}?width=300&height=200&quality=85
```

Response:
```json
{
  "cdn_url": "https://cdn.yourdomain.com/uploads/user123/image.jpg?w=300&h=200&q=85",
  "key": "uploads/user123/image.jpg",
  "optimized": true
}
```

### Download with CDN
```http
GET /media/download/{key}
```

Response (CDN enabled):
```json
{
  "url": "https://cdn.yourdomain.com/uploads/user123/song.mp3",
  "type": "cdn"
}
```

Response (CDN disabled):
```json
{
  "url": "https://r2-presigned-url...",
  "type": "presigned"
}
```

### Public Media with Redirect
```http
GET /media/public/{key}?redirect=true&width=300
```

- If `redirect=true` and CDN enabled: Returns 302 redirect to CDN
- Otherwise: Streams file directly from backend

## 🎨 Frontend Integration

### Using CDN URLs in Flutter

Update your Flutter app to use CDN URLs:

```dart
// In your media service
Future<String> getMediaUrl(String r2Key, {int? width, int? height}) async {
  final base = Uri.parse(apiBaseUrl);
  
  // Check if CDN is enabled (you can add this to API config)
  final cdnUri = base.replace(
    path: '${base.path}/media/cdn/${Uri.encodeComponent(r2Key)}',
    queryParameters: {
      if (width != null) 'width': width.toString(),
      if (height != null) 'height': height.toString(),
    }
  );
  
  final response = await http.get(cdnUri);
  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['cdn_url'] as String;
  }
  
  // Fallback to public URL
  return base.replace(
    path: '${base.path}/media/public/${Uri.encodeComponent(r2Key)}'
  ).toString();
}
```

### Image Widget with CDN

```dart
Image.network(
  await getMediaUrl(coverPhotoKey, width: 300, height: 300),
  fit: BoxFit.cover,
)
```

## 🔒 Security Considerations

1. **Public Access**
   - Only files in `uploads/` are accessible
   - Private files should use presigned URLs

2. **CORS**
   - CDN endpoints allow CORS from any origin
   - Restrict in production if needed

3. **Rate Limiting**
   - Cloudflare provides built-in DDoS protection
   - Configure rate limits in Cloudflare dashboard

4. **Access Control**
   - Use `/media/download/` for authenticated access
   - Use `/media/public/` only for public assets

## 📈 Performance Benefits

### Before CDN:
- Load time: 500-2000ms (depending on location)
- Bandwidth: 100% from backend
- Image size: Original (large)
- Cache: Browser only

### After CDN:
- Load time: 50-200ms (served from nearest edge)
- Bandwidth: 90%+ from CDN cache
- Image size: Optimized (WebP/AVIF, resized)
- Cache: Edge + Browser (multi-layer)

## 🐛 Troubleshooting

### CDN Not Working?

1. **Check CDN is enabled**
   ```bash
   docker-compose exec backend python -c "from app.cdn_config import is_cdn_enabled; print(is_cdn_enabled())"
   ```

2. **Verify DNS**
   ```bash
   nslookup cdn.yourdomain.com
   ```

3. **Check Cloudflare Dashboard**
   - R2 → Your Bucket → Settings → Custom Domain
   - Verify domain is connected

4. **Test Direct CDN Access**
   ```bash
   curl -I https://cdn.yourdomain.com/uploads/test/image.jpg
   ```

### Images Not Optimizing?

1. **Check Image Resizing is enabled**
   - Cloudflare Image Resizing requires paid plan or Workers
   - Free tier: Use Worker for optimization

2. **Verify Query Parameters**
   - Must include `w`, `h`, or `q` parameters
   - Format: `?w=300&h=200&q=85`

### Worker Not Deploying?

1. **Check Wrangler Login**
   ```bash
   wrangler whoami
   ```

2. **Verify R2 Binding**
   - Check `wrangler.toml` has correct bucket name
   - Ensure bucket exists in your account

3. **Check Worker Logs**
   ```bash
   wrangler tail
   ```

## 💰 Cost Considerations

### Free Tier:
- ✅ R2 Custom Domain (free CDN)
- ✅ 10GB R2 storage
- ✅ 1M Class A operations/month
- ✅ 10M Class B operations/month
- ❌ Image Resizing (requires Workers paid plan)

### Paid Plans:
- **Workers Paid**: $5/month + usage
  - Includes Image Resizing
  - 10M requests included
- **R2**: $0.015/GB storage
  - $0.36/GB egress (but free with Custom Domain!)

## 🎯 Best Practices

1. **Use CDN for all public assets**
   - Images, audio, video
   - Static files

2. **Optimize images at upload**
   - Resize before upload
   - Use appropriate quality

3. **Cache aggressively**
   - Images: 1 year
   - Media: 1 hour
   - Dynamic: 1 day

4. **Monitor usage**
   - Check Cloudflare Analytics
   - Monitor R2 usage
   - Track CDN hit rates

5. **Use WebP/AVIF**
   - Cloudflare auto-converts
   - 30-50% smaller files

## 📚 Additional Resources

- [Cloudflare R2 Custom Domains](https://developers.cloudflare.com/r2/buckets/custom-domains/)
- [Cloudflare Image Resizing](https://developers.cloudflare.com/images/)
- [Cloudflare Workers](https://developers.cloudflare.com/workers/)
- [CDN Best Practices](https://developers.cloudflare.com/cache/)

## ✅ Checklist

- [ ] R2 bucket created
- [ ] Custom domain configured
- [ ] Environment variables set
- [ ] Backend restarted
- [ ] CDN URLs tested
- [ ] Image optimization verified
- [ ] Frontend updated to use CDN
- [ ] Monitoring set up
- [ ] Cache headers verified

---

**Your CDN is now ready for production! 🚀**
