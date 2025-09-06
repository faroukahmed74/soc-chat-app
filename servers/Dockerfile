# Production FCM Server Dockerfile
FROM node:18-alpine AS base

# Install dependencies for native modules
RUN apk add --no-cache python3 make g++

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Remove development dependencies
RUN npm prune --production

# Create non-root user
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Copy application code
COPY . .

# Change ownership to non-root user
RUN chown -R nodejs:nodejs /app
USER nodejs

# Create necessary directories
RUN mkdir -p /app/logs /app/uploads

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

# Start the application
CMD ["npm", "start"]

# Multi-stage build for development
FROM base AS development

# Install development dependencies
USER root
RUN npm install --only=dev
USER nodejs

# Development command
CMD ["npm", "run", "dev"]

# Production stage with additional security
FROM base AS production

# Security: Remove unnecessary files
RUN rm -rf /app/test /app/docs /app/*.md /app/.env*

# Security: Set read-only filesystem for non-essential directories
RUN chmod -R 755 /app && \
    chmod -R 444 /app/logs && \
    chmod -R 444 /app/uploads

# Security: Add security headers
ENV NODE_ENV=production
ENV NODE_OPTIONS="--max-old-space-size=512"

# Production command
CMD ["npm", "run", "prod"]


