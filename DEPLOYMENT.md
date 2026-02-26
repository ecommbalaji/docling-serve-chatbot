# Deployment Guide

## Railway Deployment

### Step 1: Create New Service on Railway

1. Go to [Railway Dashboard](https://railway.app)
2. Open your project
3. Click **New** → **Service**
4. Select **Docker Image**

### Step 2: Configure Image

In the service settings:

```
Image: ghcr.io/ecommbalaji/docling-serve-chatbot:latest
```

### Step 3: Set Environment Variables

Copy these into Railway dashboard (Railway → docker-serve → Variables):

```bash
# CRITICAL - Redis Queue Connection
REDIS_URL=redis://redis.railway.internal:6379/2

# CRITICAL - Model Configuration (pre-baked in image)
DOCLING_SERVE_ARTIFACTS_PATH=/opt/app-root/src/models
DOCLING_SERVE_LOAD_MODELS_AT_BOOT=false
DOCLING_SERVE_SCRATCH_PATH=/app/scratchpad

# RECOMMENDED - UI and Logging
DOCLING_SERVE_ENABLE_UI=1
DOCLING_SERVE_LOG_LEVEL=INFO
```

### Step 4: Mount Volume

Add a volume mount for scratchpad:

**Mount Path**: `/app/scratchpad`

(This is where docling stores temporary files during processing)

### Step 5: Configure Port

- **Port**: `8000`
- **Public URL** will be auto-assigned (e.g., `docling-serve-abc123.railway.app`)

### Step 6: Deploy

Click **Deploy** and wait for startup (2-3 minutes)

Check logs for:
```
INFO:rq.worker:*** Listening on convert...
```

This means docling-serve is ready!

## Verify Deployment

### Check Service Status

```bash
# SSH into Railway or check logs
curl https://docling-serve-abc123.railway.app/ui
```

Should see the Docling UI.

### Test RQ Worker

```bash
# Check if worker is listening
redis-cli -u redis://redis-XXXXX.railway.internal:6379/2
> KEYS "rq:*"
> LLEN "rq:queue:convert"
```

Should show the queue is ready.

## Connect File/Web Workers

Update your file-worker and web-worker services with:

```bash
DOCLING_SERVE_ENG_RQ_REDIS_URL=redis://redis-XXXXX.railway.internal:6379/2
DOCLING_RQ_QUEUE_NAME=convert
```

Both workers will now enqueue jobs to docling-serve.

## Monitoring

### View Logs

```bash
# Real-time logs
railway logs -f

# Recent logs with grep
railway logs | grep "RQ\|DOCLING"
```

### Watch for Issues

**If models not loading:**
```
ERROR: Models not found at /opt/app-root/src/models/RapidOcr
```
→ Verify `DOCLING_SERVE_ARTIFACTS_PATH=/opt/app-root/src/models`

**If queue not listening:**
```
ERROR: Could not connect to Redis
```
→ Verify `REDIS_URL` is correct and Redis service is running

**If jobs stuck in queue:**
```
WARN: No worker listening on 'convert' queue
```
→ Check docling-serve logs for crashes

### Performance

- **Startup time**: 2-3 minutes
- **Processing time per page**:
  - Simple PDF: 10-30 seconds
  - Complex PDF with images: 1-5 minutes
  - Web page: 20-60 seconds

## Scaling

### Multiple Instances

To process more documents in parallel, deploy multiple docling-serve instances:

1. Create 2-3 services (each uses same Redis DB 2)
2. Each instance runs `rq-worker` on `convert` queue
3. Jobs automatically distributed across instances

### Memory/CPU

Recommended for Railway:

- **CPU**: 2-4 vCPUs
- **Memory**: 4-8 GB
- **Disk**: 20 GB (temp processing space)

## Troubleshooting

### Slow Startup

First startup downloads models (~5GB). This image has them pre-cached, so startup should be 2-3 minutes. If slower:

1. Check Railway logs for errors
2. Verify `DOCLING_SERVE_LOAD_MODELS_AT_BOOT=false` is set
3. Confirm volume is mounted for scratchpad

### Jobs Not Processing

1. Check Redis connectivity:
   ```bash
   redis-cli -u $REDIS_URL ping
   # Should respond: PONG
   ```

2. Check worker is listening:
   ```bash
   redis-cli -u $REDIS_URL KEYS "rq:workers:*"
   # Should show worker ID
   ```

3. Check job queue:
   ```bash
   redis-cli -u $REDIS_URL LLEN "rq:queue:convert"
   # Should show pending jobs
   ```

### Out of Memory

If docling-serve crashes with OOM:

1. Increase Railway instance memory to 8GB+
2. Reduce concurrent file size limit
3. Add multiple instances to distribute load

## Building Locally

To test before pushing to Railway:

```bash
# Build image
docker build -t docling-serve-chatbot:latest .

# Run with local Redis
docker run -d \
  --name docling-serve \
  -p 8000:8000 \
  -e REDIS_URL=redis://host.docker.internal:6379/2 \
  -e DOCLING_SERVE_ARTIFACTS_PATH=/opt/app-root/src/models \
  -e DOCLING_SERVE_LOAD_MODELS_AT_BOOT=false \
  -e DOCLING_SERVE_SCRATCH_PATH=/app/scratchpad \
  -v /tmp/docling-scratchpad:/app/scratchpad \
  docling-serve-chatbot:latest

# Access UI
curl http://localhost:8000/ui

# Clean up
docker stop docling-serve
docker rm docling-serve
```

## GitHub Container Registry

The image is automatically built and pushed to GHCR on every push to main branch.

**Image available at:**
```
ghcr.io/ecommbalaji/docling-serve-chatbot:latest
```

Tags:
- `latest` - Latest build
- `main-<sha>` - Specific commit
- `vX.Y.Z` - Version tags (if used)

## Next Steps

1. ✅ Deploy docling-serve on Railway
2. ✅ Configure file-worker and web-worker to use it
3. ✅ Test by uploading a PDF file
4. ✅ Monitor logs for processing
5. ✅ Scale as needed for load

For more help, see [README.md](README.md) or open an issue.
