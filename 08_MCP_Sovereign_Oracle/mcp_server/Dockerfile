FROM node:20-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY tsconfig.json ./
COPY src/ src/
COPY config/ config/

RUN npm run build

# ─── Production image ────────────────────────────────────────────────

FROM node:20-alpine

# Security hardening: create non-root user
RUN addgroup -S grimoire && adduser -S oracle -G grimoire

WORKDIR /app

COPY --from=builder /app/package.json /app/package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY --from=builder /app/dist/ dist/
COPY --from=builder /app/config/ config/

# Filesystem security: make app files read-only
RUN chown -R oracle:grimoire /app && \
    chmod -R 555 /app/dist /app/config && \
    chmod 444 /app/package.json

# Copy the grimoire knowledge base (docs, contracts, etc.)
# Mount as read-only volume in production: -v /path/to/repo:/grimoire:ro
ENV GRIMOIRE_REPO_PATH=/grimoire
ENV PORT=8402
ENV NODE_ENV=production

# Run as non-root user
USER oracle

EXPOSE 8402

# Security: drop all capabilities, read-only root filesystem compatible
# Run with: docker run --read-only --cap-drop ALL --security-opt no-new-privileges
CMD ["node", "dist/server.js"]
