# backup-postgresql-s3
Simple script for backing up a PostgreSQL database to an S3 (minio) bucket.

# Configuration

```bash
# Required environment variables
POSTGRES_HOST='localhost'
POSTGRES_USER='user'
POSTGRES_PASSWORD='password'
POSTGRES_DATABASE='mydb'
POSTGRES_TABLES='mydb.table1;mydb.table2'
MINIO_ENDPOINT='http://localhost:9000'
MINIO_ACCESS_KEY='minioadmin'
MINIO_SECRET_KEY='minioadmin'

# Optional variables
POSTGRES_PORT=5432
MINIO_BUCKET='postgres-backups'
MINIO_PATH='postgres-backups'
RETENTION_PERIOD='7d'
MINIO_COMMAND='mc'
DISCORD_WEBHOOK_URL=''
```

# Description

When running the script, it will connect to the specified postgres database, create a backup for each specified table by extracting its contents using pg_dump, compress it and upload it to the specified S3 bucket.

It will also remove backups older than the specified number of days.
To disable this feature, leave `RETENTION_PERIOD` empty.

`POSTGRES_TABLES` can be used to specify the tables to back up, separated by semicolons.

Backups will be stored under the specified `MINIO_PATH` in the bucket `MINIO_BUCKET`, with filenames in the format `<database>_<table>_YYYYMMDD_HHMMSS.sql.gz`.

When setting `DISCORD_WEBHOOK_URL`, a notification will be sent to the specified Discord webhook when the backup fails.