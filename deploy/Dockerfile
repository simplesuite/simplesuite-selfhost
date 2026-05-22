# Stage 1: Build the React application from the frontend repo
FROM node:22-alpine AS build

RUN apk add --no-cache git

WORKDIR /app

# Clone the latest frontend source
RUN git clone --depth 1 https://github.com/simplebudgets/simplebudget.git .

# Install dependencies and build
RUN npm ci
RUN npm run build

# Stage 2: Serve with Caddy
FROM caddy:2-alpine

# Copy built assets to Caddy's serving directory
COPY --from=build /app/build /usr/share/caddy

# Copy Caddy configuration
COPY Caddyfile /etc/caddy/Caddyfile

# Copy config writer script and make it executable
COPY scripts/write-config.sh /usr/local/bin/write-config.sh
RUN chmod +x /usr/local/bin/write-config.sh

# Generate config.json at startup, then start Caddy
CMD ["sh", "-c", "/usr/local/bin/write-config.sh && caddy run --config /etc/caddy/Caddyfile"]
