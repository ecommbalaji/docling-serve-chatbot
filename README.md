# Docling Serve Chatbot

🚀 Pre-built Docker image of [Docling Serve](https://github.com/DS4SD/docling-serve) with **all models pre-downloaded and cached** for fast startup on Railway or Kubernetes.

## What's Included

✅ **Docling Serve** - Document conversion service with OCR, layout detection, table understanding
✅ **Pre-downloaded Models** - RapidOCR and all Docling models baked into the image
✅ **Fast Startup** - 2-3 minutes instead of 10+ minutes (models don't need to download)
✅ **Redis Queue Support** - Ready for RQ mode with file/web workers

## Quick Start

### Pull from GitHub Container Registry

```bash
docker pull ghcr.io/ecommbalaji/docling-serve-chatbot:latest
```

### Run Locally

```bash
docker run -d \
  --name docling-serve \
  -p 8000:8000 \
  -e REDIS_URL=redis://host.docker.internal:6379/2 \
  -e DOCLING_SERVE_ARTIFACTS_PATH=/opt/app-root/src/models \
  -e DOCLING_SERVE_LOAD_MODELS_AT_BOOT=false \
  -e DOCLING_SERVE_SCRATCH_PATH=/app/scratchpad \
  -v /tmp/docling-scratchpad:/app/scratchpad \
  ghcr.io/ecommbalaji/docling-serve-chatbot:latest
```

### Deploy on Railway

1. **Create new service** on Railway
2. **Select "Docker Image"** as the source
3. **Set image** to `ghcr.io/ecommbalaji/docling-serve-chatbot:latest`
4. **Configure environment variables**:

```bash
# Critical
REDIS_URL=redis://redis.railway.internal:6379/2
DOCLING_SERVE_ARTIFACTS_PATH=/opt/app-root/src/models
DOCLING_SERVE_LOAD_MODELS_AT_BOOT=false
DOCLING_SERVE_SCRATCH_PATH=/app/scratchpad

# Optional
DOCLING_SERVE_ENABLE_UI=1
DOCLING_SERVE_LOG_LEVEL=INFO
```

5. **Mount volume** for scratchpad:
   - Mount path: `/app/scratchpad`

## How It Works

### Multi-stage Docker Build with Caching

The Dockerfile uses a two-stage build:

**Stage 1: Model Cache**
```dockerfile
FROM quay.io/docling-project/docling-serve:latest AS model-cache
RUN docling-tools models download --all -o /opt/app-root/src/models
```
- Downloads and caches all models as a separate layer
- This layer is reused on subsequent builds (unless models change)
- ~5GB, cached by GitHub Actions

**Stage 2: Runtime**
```dockerfile
FROM quay.io/docling-project/docling-serve:latest
COPY --from=model-cache /opt/app-root/src/models /opt/app-root/src/models
```
- Reuses the cached models from stage 1
- Final image is ready to run without downloading models

### GitHub Actions Caching

The workflow uses:
- **Docker BuildKit** for layer caching
- **GitHub Actions cache** to store build layers between runs
- **Multi-stage build** to optimize cache hits

First build: ~15 minutes (downloads 5GB of models)
Subsequent builds: ~2 minutes (uses cache)

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REDIS_URL` | - | Redis connection for RQ queue (DB 2) |
| `DOCLING_SERVE_ARTIFACTS_PATH` | `/opt/app-root/src/models` | Path to pre-downloaded models (set by image) |
| `DOCLING_SERVE_LOAD_MODELS_AT_BOOT` | `false` | Skip model download at startup (models in image) |
| `DOCLING_SERVE_SCRATCH_PATH` | `/app/scratchpad` | Temporary directory for processing |
| `DOCLING_SERVE_ENABLE_UI` | `1` | Enable web UI at /ui |
| `DOCLING_SERVE_LOG_LEVEL` | `INFO` | Logging level (DEBUG, INFO, WARNING, ERROR) |

## Connecting to File/Web Workers

### File Worker Configuration

```bash
DOCLING_SERVE_ENG_RQ_REDIS_URL=redis://redis-XXXXX.railway.internal:6379/2
DOCLING_RQ_QUEUE_NAME=convert
```

### Web Worker Configuration

```bash
DOCLING_SERVE_ENG_RQ_REDIS_URL=redis://redis-XXXXX.railway.internal:6379/2
DOCLING_RQ_QUEUE_NAME=convert
```

Both workers enqueue jobs to the `convert` queue that docling-serve listens on.

## Models Included

The image comes with all Docling models pre-downloaded:

- **RapidOCR** - Fast OCR for text extraction
- **Layout Detection** - Page layout analysis
- **Table Structure Recognition** - Table cell detection and merging
- **Chart Extraction** - Chart identification
- **Formula Enrichment** - Mathematical formula handling

Total size: ~5GB (included in image)

## Building Locally

```bash
# Build the image
docker build -t docling-serve-chatbot:latest .

# Run it
docker run -d \
  -p 8000:8000 \
  -e REDIS_URL=redis://localhost:6379/2 \
  docling-serve-chatbot:latest
```

## Health Check

The image includes a health check that verifies docling-serve is responsive:

```bash
curl http://localhost:8000/ui
```

## Architecture

```
┌─────────────────────────────────────────────┐
│  File/Web Worker (on Railway/Kubernetes)   │
│  Enqueue job to "convert" queue            │
└────────────────────┬────────────────────────┘
                     │
                     ↓
         ┌───────────────────────┐
         │   Redis (DB 2)        │
         │  RQ Queue: convert    │
         └───────────────────────┘
                     ↑
                     │
                     ↓
    ┌──────────────────────────────────┐
    │  Docling Serve (this image)      │
    │  - Listen on "convert" queue     │
    │  - Process documents             │
    │  - Return results via Redis      │
    │  - Pre-cached models (5GB)       │
    └──────────────────────────────────┘
```

## Tags

- `latest` - Latest build from main branch
- `main-<sha>` - Specific commit SHA
- `vX.Y.Z` - Semantic version tags (if used)

## Support

- **Docling Docs**: https://ds4sd.github.io/docling/
- **Docling Serve Repo**: https://github.com/DS4SD/docling-serve
- **Issues**: Open an issue on this repository

## License

This image is built from [Docling Serve](https://github.com/DS4SD/docling-serve) which is licensed under Apache 2.0.

---

**Image Size**: ~6-7GB (includes base image + 5GB models)
**Build Time**: ~15 min (first) / ~2 min (cached)
**Startup Time**: 2-3 minutes
**Registry**: ghcr.io (public)
