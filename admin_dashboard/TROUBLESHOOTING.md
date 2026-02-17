# Admin Dashboard Troubleshooting

## Blank Screen Issues

If you see a blank screen, follow these steps:

### 1. Check Browser Console

Open browser DevTools (F12) and check the Console tab for errors. Common issues:
- Module not found errors → Dependencies not installed
- Network errors → Backend not running or CORS issues
- React errors → Check the error message

### 2. Install Dependencies

If you haven't installed dependencies yet:

```bash
cd admin_dashboard
npm install
```

### 3. Start Dev Server

```bash
npm run dev
```

The server should start on `http://localhost:3001`

### 4. Check Backend is Running

Make sure the FastAPI backend is running on `http://localhost:8000`:

```bash
# Check if backend is running
curl http://localhost:8000/

# Or check docker containers
docker-compose ps
```

### 5. Clear Browser Cache

Sometimes cached files cause issues:
- Hard refresh: `Ctrl+Shift+R` (Windows/Linux) or `Cmd+Shift+R` (Mac)
- Or clear browser cache completely

### 6. Check Network Tab

In browser DevTools → Network tab:
- Check if requests to `/api/*` are being made
- Check if they're returning 200 or error status codes
- Check if CORS errors appear

### 7. Verify Files Exist

Make sure all these files exist:
- `admin_dashboard/src/main.tsx`
- `admin_dashboard/src/App.tsx`
- `admin_dashboard/src/index.html`
- `admin_dashboard/package.json`
- `admin_dashboard/vite.config.ts`

### 8. Rebuild from Scratch

If nothing works:

```bash
cd admin_dashboard
rm -rf node_modules package-lock.json
npm install
npm run dev
```

### Common Errors

**"Cannot find module 'react'"**
→ Run `npm install`

**"Network Error" or CORS errors**
→ Check backend is running and CORS is configured

**"401 Unauthorized"**
→ You need to log in first, or your token expired

**"404 Not Found" on /api routes**
→ Check vite.config.ts proxy configuration

**Port 3001 already in use**
→ Change port in `vite.config.ts` or kill the process using port 3001

### Still Having Issues?

1. Check the browser console for specific error messages
2. Check the terminal where `npm run dev` is running for build errors
3. Verify Node.js version: `node --version` (should be 16+)
4. Try deleting `node_modules` and reinstalling
