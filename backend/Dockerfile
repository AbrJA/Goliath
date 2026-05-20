FROM rocker/r-ver:4.4.0

RUN apt-get update && apt-get install -y --no-install-recommends \
    libsqlite3-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('R6', 'data.table', 'checkmate', 'DBI', 'RSQLite', 'pool', 'forecast', 'httr', 'yyjsonr'), repos = 'https://cloud.r-project.org')"

ENV DB_PATH=/app/data/metrics.db
ENV HOME=/app

WORKDIR /app

COPY ../core ./core
RUN R -e "install.packages('./core', repos = NULL, type = 'source')"

COPY generator ./generator
COPY metrics ./metrics
COPY models ./models
COPY validations ./validations
COPY main.R .

RUN mkdir -p /app/data

ENTRYPOINT ["R", "-e", "source('main.R')"]
