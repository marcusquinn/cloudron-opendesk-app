# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 Marcus Quinn
#
# opendesk for Cloudron: the Go API/workers/web app (one static binary with an
# embedded NATS) and the Elixir realtime gateway, built from one pinned upstream
# commit with the patches in patches/, behind an internal nginx on port 8000.
# Every stage avoids BuildKit-only syntax so Cloudron's on-server build works.

ARG OPENDESK_COMMIT=06ac9a93386acf6ab7ea359e8b1ade3d04d4b30a

# ── source: the pinned upstream checkout with the Cloudron patches applied ───
# The Debian golang image ships git, so no unpinned package install is needed.
FROM golang:1.27@sha256:820153096fda4de6ac1b7194d12e416b7dd8f4e9a33d17e0345b111b945162d8 AS src
ARG OPENDESK_COMMIT
WORKDIR /src
RUN git init -q . \
    && git remote add origin https://github.com/useopendesk/opendesk.git \
    && git fetch -q --depth 1 origin "${OPENDESK_COMMIT}" \
    && git checkout -q FETCH_HEAD \
    && test "$(git rev-parse HEAD)" = "${OPENDESK_COMMIT}"
COPY patches/ /patches/
RUN for p in /patches/*.patch; do git apply --recount -v "$p"; done \
    && rm -rf .git

# ── web: the React app, chat widget and help center ─────────────────────────
FROM node:24-alpine@sha256:44fce696f38ba8c987c4db89954051000bbd05ffd8d8659ba15ed4a8602e937f AS web
ENV CI=true
WORKDIR /src
COPY --from=src /src/brand/ brand/
COPY --from=src /src/contracts/ contracts/
COPY --from=src /src/web/ web/
WORKDIR /src/web
RUN npm install -g --silent corepack@0.36.0 && corepack enable \
    && pnpm install --frozen-lockfile && pnpm build && test -f dist/index.html

# ── admin: the instance admin panel, served at /admin/ ──────────────────────
FROM node:24-alpine@sha256:44fce696f38ba8c987c4db89954051000bbd05ffd8d8659ba15ed4a8602e937f AS admin
ENV CI=true
WORKDIR /src
COPY --from=src /src/brand/ brand/
COPY --from=src /src/contracts/ contracts/
COPY --from=src /src/admin/ admin/
WORKDIR /src/admin
RUN npm install -g --silent corepack@0.36.0 && corepack enable \
    && pnpm install --frozen-lockfile && pnpm build:embed && test -f dist/index.html

# ── go: one static binary with both web builds embedded ─────────────────────
FROM golang:1.27-alpine@sha256:f92b6ef800e499660581efdabdf25d9d817a9d124eaf900924f0504e7e27e12d AS go
ARG OPENDESK_COMMIT
WORKDIR /src
COPY --from=src /src/ ./
RUN go mod download \
    && rm -rf internal/webui/dist internal/adminui/dist \
    && mkdir -p internal/webui/dist internal/adminui/dist
COPY --from=web /src/web/dist/ internal/webui/dist/
COPY --from=admin /src/admin/dist/ internal/adminui/dist/
RUN CGO_ENABLED=0 go build -trimpath \
      -ldflags "-s -w -X github.com/useopendesk/opendesk/internal/version.Version=cloudron-${OPENDESK_COMMIT} -X github.com/useopendesk/opendesk/internal/version.Commit=${OPENDESK_COMMIT}" \
      -o /out/opendesk ./cmd/opendesk \
    && /out/opendesk version

# ── realtime: the Phoenix gateway as a self-contained release (ERTS included) ─
# Built on the same Ubuntu release as cloudron/base:6.0.1 (26.04 "resolute"), so
# the crypto NIF links against the runtime's own libssl.
FROM hexpm/elixir:1.20.4-erlang-29.1.1-ubuntu-resolute-20260927@sha256:27891ab37c7677f921899bc2b9e8e2e47ac0cae17cae28bd5979839ba6b0a479 AS realtime
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends build-essential ca-certificates git \
    && rm -rf /var/lib/apt/lists/*
ENV MIX_ENV=prod
WORKDIR /build
RUN mix local.hex --force && mix local.rebar --force
COPY --from=src /src/realtime/mix.exs /src/realtime/mix.lock ./
RUN mix deps.get --only prod
COPY --from=src /src/realtime/config/ config/
RUN mix deps.compile
COPY --from=src /src/realtime/ ./
RUN mix compile && mix release realtime --overwrite

# ── runtime ─────────────────────────────────────────────────────────────────
FROM cloudron/base:6.0.1@sha256:7b1e729960c3ca312d26e886917ba89483241bba0219ff292858e10d9d5768ee
ARG OPENDESK_COMMIT
LABEL org.opencontainers.image.source="https://github.com/marcusquinn/cloudron-opendesk-app"

RUN apt-get update \
    && apt-get install -y --no-install-recommends libncurses6 libsctp1 nginx openssl supervisor \
    && rm -rf /var/lib/apt/lists/* /etc/nginx/sites-enabled/default

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8 \
    PATH=/app/code/bin:$PATH

WORKDIR /app/code
COPY --from=go /out/opendesk /app/code/opendesk
COPY --from=realtime /build/_build/prod/rel/realtime/ /app/code/realtime/
COPY start.sh nginx.conf supervisord.conf env.template /app/code/
COPY bin/ /app/code/bin/
RUN chmod 0755 /app/code/start.sh /app/code/bin/* /app/code/opendesk \
    && printf '%s\n' "${OPENDESK_COMMIT}" > /app/code/upstream-commit

EXPOSE 8000
CMD ["/app/code/start.sh"]
