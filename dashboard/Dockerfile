# Build from project root:
#   docker build -f dashboard/Dockerfile -t goliath-dashboard .
FROM ghcr.io/r-hub/r-minimal/r-minimal:4.6.0

# -d  : install C/C++ compilers, remove after packages are built
# -t  : Alpine packages needed at build time only (removed after)
# -a  : Alpine packages kept at runtime
# zlib-dev is required by httpuv (shiny dependency)
RUN installr -d \
      -t "gfortran curl-dev openssl-dev zlib-dev" \
      -a "libcurl openssl zlib tzdata" \
      R6 checkmate data.table DBI RSQLite pool forecast \
      shiny plotly bslib httr yyjsonr

ENV DB_PATH=/app/data/metrics.db
ENV TZDIR=/usr/share/zoneinfo
# Override at runtime: docker run -e TZ=America/Chicago ...
ENV TZ=UTC

WORKDIR /app

COPY core ./core
RUN R CMD INSTALL core --no-docs --no-test-load && rm -rf core

COPY dashboard/constants ./constants
COPY dashboard/functions ./functions
COPY dashboard/global.R  .
COPY dashboard/server.R  .
COPY dashboard/ui.R      .

# COPY data ./data

EXPOSE 8000

CMD ["R", "--slave", "-e", "shiny::runApp('/app', host='0.0.0.0', port=8000)"]
