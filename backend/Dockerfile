# Build from project root:
#   docker build -f backend/Dockerfile -t goliath-backend .
FROM ghcr.io/r-hub/r-minimal/r-minimal:4.6.0

# -d  : install C/C++ compilers, remove after packages are built
# -t  : Alpine packages needed at build time only (removed after)
# -a  : Alpine packages kept at runtime
RUN installr -d \
      -t "gfortran curl-dev openssl-dev" \
      -a "libcurl openssl tzdata" \
      R6 checkmate data.table DBI RSQLite pool forecast httr yyjsonr

ENV DB_PATH=/app/data/metrics.db
ENV TZDIR=/usr/share/zoneinfo

WORKDIR /app

COPY core ./core
RUN R CMD INSTALL core --no-docs --no-test-load && rm -rf core

COPY backend/generator ./generator
COPY backend/metrics   ./metrics
COPY backend/models    ./models
COPY backend/validations ./validations
COPY backend/main.R    .

RUN mkdir -p /app/data

ENTRYPOINT ["R", "--slave", "-e", "source('main.R')"]
