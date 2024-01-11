FROM quay.io/tembo/tembo-local:latest

# Optional:
# Install any extensions you want with Trunk
RUN trunk install pg_cron
RUN trunk install pg_partman
RUN trunk install prometheus_fdw
RUN trunk install pgsql_http

# Optional:
# Specify extra Postgres configurations by copying into this directory
COPY custom.conf $PGDATA/extra-configs

# Optional:
# Specify startup SQL scripts by copying into this directory
COPY startup.sql $PGDATA/startup-scripts
