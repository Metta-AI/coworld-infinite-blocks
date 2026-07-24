# Build Docker.
FROM debian:bookworm-slim AS build

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git && \
  rm -rf /var/lib/apt/lists/*

RUN if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
    curl -fsSL \
      -o /usr/local/bin/nimby \
https://github.com/treeform/nimby/releases/download/0.1.26/nimby-Linux-X64; \
  elif [ "$(dpkg --print-architecture)" = "arm64" ]; then \
    curl -fsSL \
      -o /usr/local/bin/nimby \
https://github.com/treeform/nimby/releases/download/0.1.26/nimby-Linux-ARM64; \
  else \
    echo "unsupported arch: $(dpkg --print-architecture)" && exit 1; \
  fi && \
  chmod +x /usr/local/bin/nimby && \
  nimby use 2.2.4

ENV PATH="/root/.nimby/nim/bin:$PATH"

WORKDIR /workspace/coworld-infinite-blocks
COPY nimby.lock .
RUN nimby sync nimby.lock -g

COPY . .
RUN nimby sync nimby.lock -g
# The repo nim.cfg carries local dev paths; regenerate it from the
# locked packages nimby sync installed into the container.
RUN rm -f nim.cfg && \
  for d in /root/.nimby/pkgs/*; do \
    if [ -d "$d/src" ]; then echo "--path:\"$d/src\""; \
    else echo "--path:\"$d\""; fi; \
  done > nim.cfg
RUN nim c \
  -d:release \
  --path:src \
  --nimcache:/tmp/coworld-nimcache \
  --out:/bin/polite \
  players/polite/polite.nim

# Run Docker.
FROM debian:bookworm-slim

RUN apt-get update && \
  apt-get install -y --no-install-recommends libssl3 ca-certificates && \
  rm -rf /var/lib/apt/lists/*

COPY --from=build /bin/polite /bin/polite

CMD ["/bin/polite"]
