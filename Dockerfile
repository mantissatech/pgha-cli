# pgha container image: the CLI and the web console.
#
# Built from the released Linux binaries of this repository, not from
# source. The fetch stage downloads the archive for the target platform
# and checks it against checksums.txt from the same release.
#
#   docker build --build-arg VERSION=v0.1.11 -t pgha .
#   docker run --rm -p 127.0.0.1:7070:7070 -v pgha-data:/data -e HCLOUD_TOKEN pgha
#
# /data holds pgha.db and the SSH key (/data/.ssh). It is also the
# home directory of the pgha user, so ssh and pgha find the key there.
# Docs: https://mantissatech.github.io/pgha-cli/docs/container-image/

ARG ALPINE_VERSION=3.24

FROM --platform=$BUILDPLATFORM alpine:${ALPINE_VERSION} AS fetch
RUN apk add --no-cache curl
ARG VERSION
ARG TARGETOS
ARG TARGETARCH
WORKDIR /fetch
RUN set -eu; \
    test -n "${VERSION}" || { echo "set --build-arg VERSION=vX.Y.Z" >&2; exit 1; }; \
    base="https://github.com/mantissatech/pgha-cli/releases/download/${VERSION}"; \
    file="pgha_${TARGETOS}_${TARGETARCH}.tar.gz"; \
    curl -fsSLO "${base}/${file}"; \
    curl -fsSLO "${base}/checksums.txt"; \
    grep " ${file}\$" checksums.txt | sha256sum -c -; \
    tar -xzf "${file}" pgha; \
    install -m 0755 pgha /pgha

FROM alpine:${ALPINE_VERSION}
RUN apk add --no-cache ca-certificates openssh-client tini tzdata \
 && addgroup -S -g 10001 pgha \
 && adduser -S -D -u 10001 -G pgha -h /data -s /sbin/nologin pgha \
 && install -d -o pgha -g pgha -m 0700 /data /data/.ssh
COPY --from=fetch /pgha /usr/local/bin/pgha
COPY docker/entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# The console binds all interfaces inside the container, but answers
# only loopback names until PGHA_CONSOLE_ALLOWED_HOSTS lists yours.
ENV HOME=/data \
    PGHA_DB=/data/pgha.db \
    PGHA_CONSOLE_LISTEN=0.0.0.0:7070 \
    PGHA_CONSOLE_ALLOWED_HOSTS=localhost
WORKDIR /data
VOLUME /data
USER pgha
EXPOSE 7070

ENTRYPOINT ["/sbin/tini", "--", "docker-entrypoint.sh"]
CMD ["console"]
