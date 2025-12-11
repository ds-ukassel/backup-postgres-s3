FROM alpine:latest

RUN --mount=type=cache,target=/etc/apk/cache apk add --update-cache bash curl gzip postgresql-client tar minio-client

COPY scripts/backup-postgres.sh /usr/local/bin/backup-postgres.sh
RUN chmod +x /usr/local/bin/backup-postgres.sh

ENV MINIO_COMMAND="mcli"
CMD ["/usr/local/bin/backup-postgres.sh"]
