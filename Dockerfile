# Multi-stage build for docling-serve with cached model layers
# This ensures models are cached as separate layers for faster rebuilds

# Stage 1: Download and cache models
FROM quay.io/docling-project/docling-serve-cpu AS model-cache

# Set working directory
WORKDIR /opt/app-root/src

# Download essential models - this creates a cacheable layer
# Skipping --all flag to avoid unnecessary vision models
# Downloads: OCR, layout detection, table structure models only
RUN docling-tools models download -o /opt/app-root/src/models

# Verify models were downloaded
RUN ls -la /opt/app-root/src/models/ && \
    echo "✅ Models downloaded successfully"


# Stage 2: Final runtime image
FROM quay.io/docling-project/docling-serve-cpu

# Set the artifacts path to point to the pre-downloaded models
ENV DOCLING_SERVE_ARTIFACTS_PATH=/opt/app-root/src/models
ENV DOCLING_SERVE_SCRATCH_PATH=/app/scratchpad

# Copy models from cache stage (this reuses the cached layer from stage 1)
COPY --from=model-cache /opt/app-root/src/models /opt/app-root/src/models

# Create scratchpad directory for temporary processing files
# Note: Must run as root to create in /app
USER root
RUN mkdir -p /app/scratchpad && \
    chmod 1777 /app/scratchpad && \
    echo "✅ Scratchpad directory created at /app/scratchpad"

# Return to original user if needed
USER 1001

# Verify models exist in final image
RUN ls -la /opt/app-root/src/models/ && \
    ls -la /app/scratchpad && \
    echo "✅ Docling-serve ready with pre-cached models and scratchpad"

# Document the image
LABEL org.opencontainers.image.title="Docling Serve Chatbot"
LABEL org.opencontainers.image.description="Docling Serve with pre-downloaded RapidOCR models for document processing"
LABEL org.opencontainers.image.source="https://github.com/ecommbalaji/docling-serve-chatbot"
LABEL org.opencontainers.image.documentation="https://github.com/ecommbalaji/docling-serve-chatbot"

# Expose the docling-serve API port
EXPOSE 8000

# No default command - Railway will provide the start command
# This allows flexibility for different runtime configurations
