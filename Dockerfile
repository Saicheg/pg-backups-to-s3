ARG POSTGRES_VERSION=17

FROM postgres:${POSTGRES_VERSION}-alpine

SHELL ["/bin/sh", "-o", "pipefail", "-e", "-u", "-x", "-c"]

USER root

RUN apk add --update --no-cache \
    gzip coreutils curl gettext aws-cli jq \
    bash gnupg openssl bzip2 xz \
    && rm -rf /var/cache/apk/*

WORKDIR /opt

COPY backup.sh /opt/scripts/backup.sh
COPY crontab /opt/crontab
COPY entrypoint.sh /opt/scripts/entrypoint.sh

RUN chmod +x /opt/scripts/entrypoint.sh /opt/scripts/backup.sh \
    && touch /var/log/cron.log \
    && echo -e "root\npostgres" > /etc/cron.allow

ENTRYPOINT ["sh", "-c", "/opt/scripts/entrypoint.sh;"]
