ARG BASE_IMAGE=senzing/senzing-base
FROM ${BASE_IMAGE}

ENV REFRESHED_AT=2019-05-01

LABEL Name="senzing/senzing-poc-utility" \
      Maintainer="support@senzing.com" \
      Version="1.0.0"

HEALTHCHECK CMD ["/app/healthcheck.sh"]

# Install packages via apt.

RUN apt-get update \
 && apt-get -y install \
    build-essential \
    curl \
    fio \
    htop \
    iotop \
    ipython \
    itop \
    jq \
    less \
    net-tools \
    pstack \
    python-dev \
    python-pip \
    python3-dev \
    python3-pip \
    python-setuptools \
    tree \
    vim \
 && rm -rf /var/lib/apt/lists/*

# Install packages via pip.

RUN pip install \
    csvkit \
    fuzzywuzzy \
    python-levenshtein \
    pyodbc \
    setuptools

# Install packages via pip3.

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
