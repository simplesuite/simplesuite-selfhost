# Stage 1: Build the React application
FROM node:22-alpine AS build

WORKDIR /app

# Copy package files and install dependencies
COPY package.json package-lock.json ./
RUN npm ci

# Copy source files and build
COPY . .
RUN npm run build

# Stage 2: Serve with Caddy
FROM caddy:2-alpine

# Copy built assets to Caddy's serving directory
COPY --from=build /app/dist /usr/share/caddy

# Copy Caddy configuration
COPY deploy/Caddyfile /etc/caddy/Caddyfile

# Copy config writer script and make it executable
COPY deploy/scripts/write-config.sh /usr/local/bin/write-config.sh
RUN chmod +x /usr/local/bin/write-config.sh

# Generate config.json at startup, then start Caddy
CMD ["sh", "-c", "/usr/local/bin/write-config.sh && caddy run --config /etc/caddy/Caddyfile"]
