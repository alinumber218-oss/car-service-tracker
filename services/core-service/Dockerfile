# ---- Build stage ----
FROM node:20-alpine AS builder
WORKDIR /app

COPY package*.json ./
RUN npm install

COPY tsconfig.json ./
COPY src ./src
RUN npm run build
# tsc only compiles .ts files - copy the raw .sql migrations alongside the
# compiled migrate.js so the runtime migration runner can find them.
RUN mkdir -p dist/db/migrations && cp -r src/db/migrations/. dist/db/migrations/

# ---- Production stage ----
FROM node:20-alpine AS production
WORKDIR /app
ENV NODE_ENV=production

COPY package*.json ./
RUN npm install --omit=dev

COPY --from=builder /app/dist ./dist

USER node
EXPOSE 4002
CMD ["node", "dist/index.js"]
