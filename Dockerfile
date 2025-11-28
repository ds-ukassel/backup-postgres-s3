FROM alpine:latest

RUN --mount=type=cache,target=/etc/apk/cache apk add bash curl gzip postgresql-client tar minio-client

COPY scripts/backup-postgresql.sh /usr/local/bin/backup-postgresql.sh
RUN chmod +x /usr/local/bin/backup-postgresql.sh

ENV MINIO_COMMAND="mcli"
CMD ["/usr/local/bin/backup-postgresql.sh"]
