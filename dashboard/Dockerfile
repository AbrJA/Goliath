FROM rocker/shiny:4.4.0

RUN apt-get update && apt-get install -y --no-install-recommends \
    libsqlite3-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('R6', 'data.table', 'checkmate', 'DBI', 'RSQLite', 'pool', 'forecast', 'plotly', 'bslib', 'httr', 'yyjsonr'), repos = 'https://cloud.r-project.org')"

WORKDIR /app

ENV DB_PATH=/app/data/metrics.db
ENV HOME=/app

COPY ../core ./core
RUN R -e "install.packages('./core', repos = NULL, type = 'source')"

COPY constants ./constants
COPY functions ./functions
COPY global.R .
COPY server.R .
COPY ui.R .

EXPOSE 8000

CMD ["R", "-e", "shiny::runApp('/app', host = '0.0.0.0', port = 8000)"]
