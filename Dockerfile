FROM node:22-bookworm

# Create directories for clawdbot config and workspace
RUN mkdir -p /home/node/.clawdbot \
  && chown -R node:node /home/node/.clawdbot \
  && mkdir -p /home/node/clawd \
  && chown -R node:node /home/node/clawd

# Install Bun (required for build scripts)
ENV BUN_INSTALL=/home/node/.bun
RUN curl -fsSL https://bun.sh/install | bash \
  && chown -R node:node /home/node/.bun
ENV PATH="/home/node/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /app

ARG CLAWDBOT_DOCKER_APT_PACKAGES=""
RUN apt-get update \
  && if [ -n "$CLAWDBOT_DOCKER_APT_PACKAGES" ]; then \
       DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends $CLAWDBOT_DOCKER_APT_PACKAGES; \
     fi \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* \
  && chown -R node:node /app

USER node
ENV HOME=/home/node

COPY --chown=node:node package.json pnpm-lock.yaml pnpm-workspace.yaml .npmrc ./
COPY --chown=node:node ui/package.json ./ui/package.json
COPY --chown=node:node patches ./patches
COPY --chown=node:node scripts ./scripts

RUN pnpm install --frozen-lockfile

COPY --chown=node:node . .
RUN pnpm build
# Force pnpm for UI build (Bun may fail on ARM/Synology architectures)
ENV CLAWDBOT_PREFER_PNPM=1
RUN pnpm ui:install
RUN pnpm ui:build

RUN mkdir -p /home/node/.clawdbot \
  && chown -R node:node /home/node/.clawdbot

ENV HOME=/home/node
ENV NODE_ENV=production

CMD ["node", "dist/index.js"]
