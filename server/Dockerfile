FROM node:20-slim
WORKDIR /app
COPY server/package*.json ./
RUN npm install --omit=dev
COPY server/ .
COPY public/ ../public
EXPOSE 3000
CMD ["node", "src/server.js"]
