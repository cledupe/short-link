# Stage 1: Install all dependencies
FROM node:18-alpine AS builder
WORKDIR /app
COPY backend/package*.json ./
RUN npm install
COPY backend/ ./

# Stage 2: Production image
FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app ./
EXPOSE 3000
CMD ["node", "server.js"]