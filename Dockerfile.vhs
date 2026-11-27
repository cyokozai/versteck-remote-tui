# 画面の録画（docs/tapes/*.tape → docs/screens/）に使う image。make screens から呼ぶ。
# 土台は VHS の公式 image（Debian 12）。gum は対象の版 0.17.0 を上流のリリースから取り、
# 同じリリースの checksums.txt で照合してから入れる（Debian 12 の apt には gum が無いため）。
ARG VHS_IMAGE=ghcr.io/charmbracelet/vhs:v0.10.0
FROM ${VHS_IMAGE}

ARG GUM_VERSION=0.17.0

# 土台の apt の参照先は「stable」なので、Debian 12（bookworm）に固定してから入れる
RUN sed -i -e 's/^Suites: stable stable-updates$/Suites: bookworm bookworm-updates/' \
           -e 's/^Suites: stable-security$/Suites: bookworm-security/' /etc/apt/sources.list.d/debian.sources \
 && apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates curl jq make fonts-noto-cjk \
 && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    arch=$(dpkg --print-architecture); \
    deb="gum_${GUM_VERSION}_${arch}.deb"; \
    base="https://github.com/charmbracelet/gum/releases/download/v${GUM_VERSION}"; \
    tmp=$(mktemp -d); \
    curl -fsSL -o "$tmp/$deb" "$base/$deb"; \
    curl -fsSL -o "$tmp/checksums.txt" "$base/checksums.txt"; \
    (cd "$tmp" && grep -E "  ${deb}\$" checksums.txt | sha256sum -c -); \
    dpkg -i "$tmp/$deb"; \
    rm -rf "$tmp"; \
    gum --version

WORKDIR /src
ENV LANG=C.UTF-8
ENTRYPOINT ["/usr/bin/vhs"]
