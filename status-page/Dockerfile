FROM node:18-alpine

# Install ping utility
RUN apk add --no-cache iputils

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --production

# Copy application files
COPY server.js index.html ./

# Expose port
EXPOSE 3000

# Run as non-root user
USER node

CMD ["node", "server.js"]
