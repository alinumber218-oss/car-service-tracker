# syntax=docker/dockerfile:1
# Requires BuildKit (default in modern Docker Engine / `docker buildx`).

# Base image pulled through a Nexus Docker proxy repository instead of
# docker.io directly. Default keeps working out of the box against the
# public registry; override at build time once Nexus is set up:
#   docker build --build-arg BASE_REGISTRY=nexus.yourcompany.example.com:8083 .
# See docs/NEXUS.md for creating the Nexus Docker proxy repo and why the
# registry host needs its own port (Nexus exposes each Docker repo on a
# distinct port/connector).
ARG BASE_REGISTRY=docker.io/library

# ---- Build stage ----
FROM ${BASE_REGISTRY}/node:20-alpine AS builder
WORKDIR /app

# .npmrc here only contains the Nexus registry URL, never the auth token -
# the token is injected via a BuildKit secret mount at build time so it
# never gets baked into an image layer or its history.
COPY package*.json .npmrc ./
RUN --mount=type=secret,id=npm_token,target=/run/secrets/npm_token \
    export NEXUS_NPM_TOKEN="$(cat /run/secrets/npm_token 2>/dev/null || true)" && \
    npm install

COPY tsconfig.json ./
COPY src ./src
RUN npm run build
# tsc only compiles .ts files - copy the raw .sql migrations alongside the
# compiled migrate.js so the runtime migration runner can find them.
RUN mkdir -p dist/db/migrations && cp -r src/db/migrations/. dist/db/migrations/

# ---- Production stage ----
FROM ${BASE_REGISTRY}/node:20-alpine AS production
WORKDIR /app
ENV NODE_ENV=production

COPY package*.json .npmrc ./
RUN --mount=type=secret,id=npm_token,target=/run/secrets/npm_token \
    export NEXUS_NPM_TOKEN="$(cat /run/secrets/npm_token 2>/dev/null || true)" && \
    npm install --omit=dev

COPY --from=builder /app/dist ./dist

USER node
EXPOSE 4001
CMD ["node", "dist/index.js"]
