# 参考: https://github.com/vercel/next.js/blob/canary/examples/with-docker/Dockerfile

# Install dependencies only when needed
FROM node:16-slim AS deps
WORKDIR /app
COPY package.json package-lock.json ./ 
RUN npm ci

FROM node:16-slim AS develop
WORKDIR /app
ENV NODE_ENV development
COPY --from=deps /app/node_modules ./node_modules
COPY . .
EXPOSE 3000
ENV PORT 3000
CMD ["npm", "run", "dev"]

# Rebuild the source code only when needed
FROM node:16-slim AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# Production image, copy all the files and run next
FROM node:16-slim AS runner
WORKDIR /app
ENV NODE_ENV production
COPY --from=builder /app/next.config.js ./
COPY --from=builder /app/package.json ./
COPY --from=builder /app/public ./public
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/.next ./.next
EXPOSE 3000
ENV PORT 3000
CMD ["npm", "run", "start"]
