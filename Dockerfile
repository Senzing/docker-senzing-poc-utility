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
    checkinstall \
    curl \
    fio \
    htop \
    iotop \
    ipython \
    itop \
    jq \
    less \
    libbz2-dev \
    libc6-dev \
    libffi-dev \
    libgdbm-dev \
    libncursesw5-dev \
    libreadline-gplv2-dev \
    libssl-dev \
    libsqlite3-dev \
    net-tools \
    pstack \
    tk-dev \
    tree \
    vim \
    zlib1g-dev \
 && rm -rf /var/lib/apt/lists/*

 # Install Python 3.7

WORKDIR /usr/src
RUN wget https://www.python.org/ftp/python/3.7.3/Python-3.7.3.tgz \
 && tar xzf Python-3.7.3.tgz \
 && cd Python-3.7.3 \
 && ./configure --enable-optimizations \
 && make altinstall

# Install packages via pip.

RUN pip install \
    csvkit \
    fuzzywuzzy \
    python-levenshtein \
    pyodbc \
    setuptools

# Install packages via pip3.7.

RUN pip3.7 install \
    csvkit \
    fuzzywuzzy \
    ptable \
    pandas \
    python-levenshtein \
    pyodbc \
    setuptools

# Set up user environment.

RUN echo 'alias ll="ls -l"' >> ~/.bashrc; \
    echo 'alias python="python3.7"' >> ~/.bashrc; \
    echo 'alias pip="pip3.7"' >> ~/.bashrc;

# Copy files from repository.

COPY ./rootfs /

# Runtime execution.

WORKDIR /app
ENTRYPOINT ["/app/docker-entrypoint.sh"]
CMD ["/app/sleep-infinity.sh"]
