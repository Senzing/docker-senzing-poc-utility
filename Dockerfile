ARG BASE_IMAGE=senzing/senzing-base:1.3.0
FROM ${BASE_IMAGE}

ENV REFRESHED_AT=2019-11-13

LABEL Name="senzing/senzing-poc-utility" \
      Maintainer="support@senzing.com" \
      Version="1.2.0"

HEALTHCHECK CMD ["/app/healthcheck.sh"]

# Run as "root" for system installation.

USER root

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

# Copy files from repository.

COPY ./rootfs /

# Set up user environment.

RUN echo "\n# Added by Dockerfile" >> >> ~/.bashrc; \
 && echo 'alias ll="ls -l"' >> >> ~/.bashrc;\
 && echo 'alias python="python3"' >> >> ~/.bashrc; \
 && echo 'alias pip="pip3"' >> >> ~/.bashrc;

# Make non-root container.

# FIXME: "alias" cannot be used with a UID that does not have a home directory.
#        Therefore, this container runs as a "root container" by default.
# USER 1001

# Runtime execution.

WORKDIR /app
CMD ["/app/sleep-infinity.sh"]
