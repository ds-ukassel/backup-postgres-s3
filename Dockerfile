FROM alpine:latest

RUN apk add --no-cache bash curl gzip postgresql-client tar minio-client

COPY scripts/backup-postgresql.sh /usr/local/bin/backup-postgresql.sh
RUN chmod +x /usr/local/bin/backup-postgresql.sh

ENV MINIO_COMMAND="mcli"
CMD ["/usr/local/bin/backup-postgresql.sh"]
