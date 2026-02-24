# ---------- Base image: matches your renv.lock R version ----------
FROM rocker/r-ver:4.5.2

# ---------- System dependencies ----------
# Core build tools (C, C++, Fortran compilers + make)
# + igraph:    libglpk-dev, libxml2-dev, gfortran
# + curl:      libcurl4-openssl-dev
# + openssl:   libssl-dev
# + gdtools/ggiraph/svglite: libcairo2-dev, libfreetype6-dev, libfontconfig1-dev
# + ggiraph/png: libpng-dev
# + magick:    libmagick++-dev
# + httpuv:    zlib1g-dev
# + stringi:   libicu-dev
# + DataExplorer/rmarkdown: pandoc
# + igraph runtime: libglpk40
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gfortran \
    libglpk-dev \
    libxml2-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libcairo2-dev \
    libfreetype6-dev \
    libfontconfig1-dev \
    libpng-dev \
    libmagick++-dev \
    zlib1g-dev \
    libicu-dev \
    pandoc \
    && rm -rf /var/lib/apt/lists/*

# ---------- Set up app directory ----------
WORKDIR /app

# ---------- Restore R packages via renv (cached layer) ----------
# Copy only renv infrastructure first so Docker can cache this expensive layer.
# The layer only rebuilds when renv.lock or activate.R change.
COPY renv.lock renv.lock
COPY renv/activate.R renv/activate.R
COPY .Rprofile .Rprofile

# Configure renv to install into a project-local library
RUN mkdir -p renv/library

# Restore all packages from the lockfile
RUN R -e "source('renv/activate.R'); renv::restore(prompt = FALSE)"

# ---------- Copy application code ----------
COPY app.R app.R
COPY rhino.yml rhino.yml
COPY config.yml config.yml
COPY dependencies.R dependencies.R
COPY app/ app/
COPY www/ www/

# ---------- Runtime configuration ----------
EXPOSE 3838

CMD ["R", "-e", "shiny::runApp('/app', host = '0.0.0.0', port = 3838)"]
