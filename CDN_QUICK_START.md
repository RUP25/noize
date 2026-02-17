# CDN Quick Start Guide

## 🚀 Quick Setup (5 minutes)

### 1. Use Public Development URL (Already Available!)

**IMPORTANT: Skip the "Custom Domain" dialog - you don't need it!**

**For Mobile Apps (No Domain Needed):**

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Navigate to: **R2** → **Your Bucket** → **Settings**
3. **Ignore "Custom Domain" section** (don't click "Connect Domain")
4. **Scroll down** to find **"Public Development URL"** section
5. Copy your URL: `pub-XXXXXXXXXXXX.r2.dev` (remove `https://`)
   - Example: `pub-49aef24dcda64ef6a9c5f4ab645605f6.r2.dev`
6. **Done!** Already active - no setup needed!

**For Web Apps (Optional):**
- Enter custom domain: `cdn.yourdomain.com`
- Wait 1-5 minutes for DNS propagation

### 2. Update Environment Variables

Add to `backend/.env`:

```env
CDN_ENABLED=true
# Use your Public Development URL (found in R2 bucket settings)
CDN_DOMAIN=pub-49aef24dcda64ef6a9c5f4ab645605f6.r2.dev  # Replace with YOUR Public Dev URL

# For Production with Custom Domain (Optional):
# CDN_DOMAIN=cdn.yourdomain.com
```

### 3. Restart Backend

```bash
docker-compose restart backend
```

### 4. Test

```bash
# Test CDN URL generation
curl http://localhost:8000/media/cdn/uploads/test/image.jpg

# Should return:
# {
#   "cdn_url": "https://cdn.yourdomain.com/uploads/test/image.jpg",
#   "key": "uploads/test/image.jpg",
#   "optimized": false
# }
```

## ✅ Done!

Your CDN is now active. All media URLs will automatically use CDN when enabled.

## 📖 Full Documentation

See `CLOUDFLARE_CDN_SETUP.md` for:
- Advanced configuration
- Image optimization
- Cloudflare Workers setup
- Frontend integration
- Troubleshooting

## 🎯 Key Benefits

- ✅ **10x faster** load times globally
- ✅ **Free** with R2 Custom Domains
- ✅ **Automatic** image optimization
- ✅ **DDoS protection** included
- ✅ **90%+ bandwidth** savings
