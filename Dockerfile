# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 Marcus Quinn
#
# opendesk for Cloudron: the Go API/workers/web app (one static binary with an
# embedded NATS) and the Elixir realtime gateway, built from one pinned upstream
# commit with the patches in patches/, behind an internal nginx on port 8000.
# Every stage avoids BuildKit-only syntax so Cloudron's on-server build works.

ARG OPENDESK_COMMIT=898e5943a232b72331daeef76678bf9093b9a210

# ── source: the pinned upstream checkout with the Cloudron patches applied ───
FROM golang:1.27-alpine@sha256:f92b6ef800e499660581efdabdf25d9d817a9d124eaf900924f0504e7e27e12d AS src
ARG OPENDESK_COMMIT
RUN apk add --no-cache git
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
RUN npm install -g --silent corepack@0.36.0 && corepack enable \
    && cd web && pnpm install --frozen-lockfile && pnpm build && test -f dist/index.html

# ── admin: the instance admin panel, served at /admin/ ──────────────────────
FROM node:24-alpine@sha256:44fce696f38ba8c987c4db89954051000bbd05ffd8d8659ba15ed4a8602e937f AS admin
ENV CI=true
WORKDIR /src
COPY --from=src /src/brand/ brand/
COPY --from=src /src/contracts/ contracts/
COPY --from=src /src/admin/ admin/
RUN npm install -g --silent corepack@0.36.0 && corepack enable \
    && cd admin && pnpm install --frozen-lockfile && pnpm build:embed && test -f dist/index.html

# ── go: one static binary with both web builds embedded ─────────────────────
FROM golang:1.27-alpine@sha256:f92b6ef800e499660581efdabdf25d9d817a9d124eaf900924f0504e7e27e12d AS go
ARG OPENDESK_COMMIT
WORKDIR /src
COPY --from=src /src/ ./
RUN go mod download
RUN rm -rf internal/webui/dist internal/adminui/dist \
    && mkdir -p internal/webui/dist internal/adminui/dist
COPY --from=web /src/web/dist/ internal/webui/dist/
COPY --from=admin /src/admin/dist/ internal/adminui/dist/
RUN CGO_ENABLED=0 go build -trimpath \
      -ldflags "-s -w -X github.com/useopendesk/opendesk/internal/version.Version=cloudron-${OPENDESK_COMMIT} -X github.com/useopendesk/opendesk/internal/version.Commit=${OPENDESK_COMMIT}" \
      -o /out/opendesk ./cmd/opendesk \
    && /out/opendesk version

# ── realtime: the Phoenix gateway as a self-contained release (ERTS included) ─
# Built on the same Ubuntu release as cloudron/base:6.0.0 (26.04 "resolute"), so
# the crypto NIF links against the runtime's own libssl.
FROM hexpm/elixir:1.20.4-erlang-29.1.1-ubuntu-resolute-20260927@sha256:27891ab37c7677f921899bc2b9e8e2e47ac0cae17cae28bd5979839ba6b0a479 AS realtime
RUN apt-get update -y \
    && apt-get install -y --no-install-recommends build-essential git ca-certificates \
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
FROM cloudron/base:6.0.0@sha256:9bed4c8fa880645f8e669041ee28febe941481d00e9445e3e5a5483cb541d09b
ARG OPENDESK_COMMIT
LABEL org.opencontainers.image.source="https://github.com/marcusquinn/cloudron-opendesk-app"

RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx supervisor libncurses6 libsctp1 openssl \
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
