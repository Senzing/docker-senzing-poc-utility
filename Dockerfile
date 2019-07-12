ARG BASE_IMAGE=senzing/senzing-base:1.0.3
FROM ${BASE_IMAGE}

ENV REFRESHED_AT=2019-07-11

LABEL Name="senzing/senzing-poc-utility" \
      Maintainer="support@senzing.com" \
      Version="1.0.1"

HEALTHCHECK CMD ["/app/healthcheck.sh"]

# Install packages via apt.

RUN apt-get update \
 && apt-get -y install \
    fio \
    htop \
    iotop \
    ipython \
    itop \
    less \
    odbc-postgresql \
    net-tools \
    pstack \
    python-pyodbc \
    unixodbc \
    unixodbc-dev \
    vim \
 && rm -rf /var/lib/apt/lists/*

# Install packages via pip.

RUN pip3 install \
    csvkit \
    fuzzywuzzy \
    ptable \
    pandas \
    python-levenshtein \
    pyodbc \
    setuptools

# Set up user environment.

RUN echo 'alias ll="ls -l"' >> ~/.bashrc; \
    echo 'alias python="python3"' >> ~/.bashrc; \
    echo 'alias pip="pip3"' >> ~/.bashrc;

# Copy files from repository.

COPY ./rootfs /

# Runtime execution.

WORKDIR /app
ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["/app/sleep-infinity.sh"]
