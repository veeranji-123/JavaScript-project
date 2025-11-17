# Multi-stage build for Node.js application with nginx
 
# Stage 1: Build argument stage (for passing Nexus credentials and URL)
FROM alpine:latest AS downloader
 
# Install curl to download from Nexus
RUN apk add --no-cache curl tar
 
# Build arguments for Nexus
ARG NEXUS_URL=http://nexus:8081
ARG NEXUS_REPO=npm-releases
ARG ARTIFACT_NAME=npm-releases
ARG ARTIFACT_VERSION=1.0.0
ARG NEXUS_USER=admin
ARG NEXUS_PASS=admin123
 
# Download artifact from Nexus
WORKDIR /tmp
RUN curl -u ${NEXUS_USER}:${NEXUS_PASS} \
    -o app.tar.gz \
    "${NEXUS_URL}/repository/${NEXUS_REPO}/${ARTIFACT_NAME}-${ARTIFACT_VERSION}.tar.gz" || \
    echo "Warning: Could not download from Nexus, will use local files"
 
# Extract artifact
RUN mkdir -p /app && \
    (tar -xzf app.tar.gz -C /app 2>/dev/null || echo "Using local files")
 
# Stage 2: Production nginx server
FROM nginx:alpine
 
# Remove default nginx static content
RUN rm -rf /usr/share/nginx/html/*
 
# Copy artifact from downloader stage (if exists) or will be copied during build
# Use RUN with shell to conditionally copy files
RUN if [ "$(ls -A /app 2>/dev/null)" ]; then \
        cp -r /app/* /usr/share/nginx/html/; \
        echo "Copied files from Nexus artifact"; \
    fi
 
# Copy local files as fallback
COPY public/* /usr/share/nginx/html/
 
# Copy custom nginx configuration if needed
# COPY nginx.conf /etc/nginx/nginx.conf
 
# Expose port 80
EXPOSE 80
 
# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --quiet --tries=1 --spider http://localhost/ || exit 1
 
# Start nginx
CMD ["nginx", "-g", "daemon off;"]
