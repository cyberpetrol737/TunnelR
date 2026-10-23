# TunnelR relay image. Build:  docker build -t tunnelr-relay .
# Run (behind a TLS-terminating reverse proxy):
#   docker run -d --name tunnelr-relay -p 127.0.0.1:8080:8080 --env-file .env \
#     -e TUNNELR_TRUST_PROXY=1 tunnelr-relay
FROM node:22-alpine

ENV NODE_ENV=production \
    TUNNELR_RELAY_HOST=0.0.0.0 \
    TUNNELR_RELAY_PORT=8080

WORKDIR /app
COPY package.json ./
COPY bin ./bin
COPY src ./src
COPY dashboard ./dashboard

# Run as the unprivileged "node" user that ships with the base image.
USER node
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.TUNNELR_RELAY_PORT||8080)+'/_tunnelr/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

ENTRYPOINT ["node", "bin/tunnelr.js"]
CMD ["relay"]
