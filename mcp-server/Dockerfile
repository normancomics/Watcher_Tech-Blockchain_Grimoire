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

WORKDIR /app

COPY --from=builder /app/package.json /app/package-lock.json ./
RUN npm ci --omit=dev

COPY --from=builder /app/dist/ dist/
COPY --from=builder /app/config/ config/

# Copy the grimoire knowledge base (docs, contracts, etc.)
# Mount as volume in production: -v /path/to/repo:/grimoire
ENV GRIMOIRE_REPO_PATH=/grimoire
ENV PORT=8402

EXPOSE 8402

# Default: HTTP server with x402 payments
CMD ["node", "dist/server.js"]
