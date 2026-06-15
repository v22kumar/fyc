# ── Stage 1: Build ───────────────────────────────────────────────────────────
FROM node:22-alpine AS builder
WORKDIR /app

ARG PUBLIC_API_BASE=http://localhost:8000
ARG PUBLIC_DEFAULT_ORG_ID=8f8b80b7-4b71-4770-b183-5c5f49e49a1d

ENV PUBLIC_API_BASE=$PUBLIC_API_BASE
ENV PUBLIC_DEFAULT_ORG_ID=$PUBLIC_DEFAULT_ORG_ID

COPY package*.json ./
RUN npm ci --prefer-offline
COPY . .
RUN npm run build

# ── Stage 2: Serve ───────────────────────────────────────────────────────────
FROM nginx:1.27-alpine AS runner
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx-static.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
