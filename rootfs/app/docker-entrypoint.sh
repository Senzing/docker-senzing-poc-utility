#!/usr/bin/env bash
# Make changes to files based on Environment Variables.

VERSION=1.0.0

# Debugging. Values: 0 for no debugging; 1 for debugging.

DEBUG=${SENZING_DEBUG:-0}

# A file used to determine if/when this program has previously run.

SENTINEL_FILE=${SENZING_ROOT}/docker-runs.sentinel

# Return codes.

OK=0
NOT_OK=1

# Location of this shell script.

SCRIPT_DIRECTORY=$(dirname ${0})

# Construct the FINAL_COMMAND.

FINAL_COMMAND="$@"

if [ ${DEBUG} -gt 0 ]; then
  echo "FINAL_COMMAND: ${FINAL_COMMAND}"
fi

# Short-circuit for certain commandline options.

if [ "$1" == "--version" ]; then
  echo "docker-entrypoint.sh version ${VERSION}"
  exit ${OK}
fi

if [ "$1" == "--sleep" ]; then
  echo "Sleeping"
  sleep 1d
  exit ${OK}
fi

# If SENZING_ENTRYPOINT_SLEEP is specified, sleep before executing.

if [ -n "${SENZING_ENTRYPOINT_SLEEP}" ]; then
  if [ ${SENZING_ENTRYPOINT_SLEEP} -gt 0 ]; then
    echo "docker-entrypoint.sh sleeping ${SENZING_ENTRYPOINT_SLEEP} seconds before execution."
    sleep ${SENZING_ENTRYPOINT_SLEEP}
  else
    echo "docker-entrypoint.sh sleeping infinitely."
    sleep infinity
  fi
fi

# Short-circuit if SENZING_DATABASE_URL not specified.

if [ -z "${SENZING_DATABASE_URL}" ]; then
  if [ ${DEBUG} -gt 0 ]; then
    echo "Using internal SQLite database"
  fi
  echo "$(date) SQLite" >> ${SENTINEL_FILE}
  exec ${FINAL_COMMAND}
  exit ${OK}
else
  echo "SENZING_DATABASE_URL: ${SENZING_DATABASE_URL}"
fi

# Verify environment variables.

if [ -z "${SENZING_ROOT}" ]; then
  echo "ERROR: Environment variable SENZING_ROOT not set."
  exit ${NOT_OK}
fi

# Parse the SENZING_DATABASE_URL.

PARSED_SENZING_DATABASE_URL=$(${SCRIPT_DIRECTORY}/parse_senzing_database_url.py)
PROTOCOL=$(echo ${PARSED_SENZING_DATABASE_URL} | jq --raw-output '.scheme')
USERNAME=$(echo ${PARSED_SENZING_DATABASE_URL} | jq --raw-output  '.username')
PASSWORD=$(echo ${PARSED_SENZING_DATABASE_URL} | jq --raw-output  '.password')
HOST=$(echo ${PARSED_SENZING_DATABASE_URL} | jq --raw-output  '.hostname')
PORT=$(echo ${PARSED_SENZING_DATABASE_URL} | jq --raw-output  '.port')
SCHEMA=$(echo ${PARSED_SENZING_DATABASE_URL} | jq --raw-output  '.schema')

if [ ${DEBUG} -gt 0 ]; then
  echo "PROTOCOL: ${PROTOCOL}"
  echo "USERNAME: ${USERNAME}"
  echo "PASSWORD: ${PASSWORD}"
  echo "    HOST: ${HOST}"
  echo "    PORT: ${PORT}"
  echo "  SCHEMA: ${SCHEMA}"
fi

# Set NEW_SENZING_DATABASE_URL.

NEW_SENZING_DATABASE_URL=""
if [ "${PROTOCOL}" == "mysql" ]; then
  NEW_SENZING_DATABASE_URL="${PROTOCOL}://${USERNAME}:${PASSWORD}@${HOST}:${PORT}/?schema=${SCHEMA}"
elif [ "${PROTOCOL}" == "postgresql" ]; then
  NEW_SENZING_DATABASE_URL="${PROTOCOL}://${USERNAME}:${PASSWORD}@${HOST}:${PORT}:${SCHEMA}/"
elif [ "${PROTOCOL}" == "db2" ]; then
  NEW_SENZING_DATABASE_URL="${PROTOCOL}://${USERNAME}:${PASSWORD}@${SCHEMA}"
else
  echo "ERROR: Unknown protocol: ${PROTOCOL}"
  exit ${NOT_OK}
fi

if [ ${DEBUG} -gt 0 ]; then
  echo "NEW_SENZING_DATABASE_URL: ${NEW_SENZING_DATABASE_URL}"
fi

# =============================================================================
# Initialization that is required every time.
# =============================================================================

# -----------------------------------------------------------------------------
# Handle "mysql" protocol.
# -----------------------------------------------------------------------------

if [ "${PROTOCOL}" == "mysql" ]; then

  cp /etc/odbc.ini.mysql-template /etc/odbc.ini
  sed -i.$(date +%s) \
    -e "s/{SCHEMA}/${SCHEMA}/g" \
    -e "s/{HOST}/${HOST}/g" \
    -e "s/{PORT}/${PORT}/g" \
    -e "s/{USERNAME}/${USERNAME}/g" \
    -e "s/{PASSWORD}/${PASSWORD}/g" \
    -e "s/{SCHEMA}/${SCHEMA}/g" \
    /etc/odbc.ini

# -----------------------------------------------------------------------------
# Handle "postgresql" protocol.
# -----------------------------------------------------------------------------

elif [ "${PROTOCOL}" == "postgresql" ]; then

  cp /etc/odbc.ini.postgresql-template /etc/odbc.ini
  sed -i.$(date +%s) \
    -e "s/{SCHEMA}/${SCHEMA}/g" \
    -e "s/{HOST}/${HOST}/g" \
    -e "s/{PORT}/${PORT}/g" \
    -e "s/{USERNAME}/${USERNAME}/g" \
    -e "s/{PASSWORD}/${PASSWORD}/g" \
    -e "s/{SCHEMA}/${SCHEMA}/g" \
    /etc/odbc.ini

# -----------------------------------------------------------------------------
# Handle "db2" protocol.
# -----------------------------------------------------------------------------

elif [ "${PROTOCOL}" == "db2" ]; then

  cp /etc/odbc.ini.db2-template /etc/odbc.ini
  sed -i.$(date +%s) \
    -e "s/{HOST}/${HOST}/g" \
    -e "s/{PORT}/${PORT}/g" \
    -e "s/{SCHEMA}/${SCHEMA}/g" \
    /etc/odbc.ini

fi

# -----------------------------------------------------------------------------
# Handle common changes.
# -----------------------------------------------------------------------------

cp /etc/odbcinst.ini.template /etc/odbcinst.ini
sed -i.$(date +%s) \
  -e "s|{SENZING_ROOT}|${SENZING_ROOT}|g" \
  /etc/odbcinst.ini

if [ ${DEBUG} -gt 0 ]; then
  echo "---------- /etc/odbc.ini ------------------------------------------------------"
  cat /etc/odbc.ini
  echo "---------- /etc/odbcinst.ini --------------------------------------------------"
  cat /etc/odbcinst.ini
  echo "-------------------------------------------------------------------------------"
fi

# =============================================================================
# Exit if one-time initialization has been previously performed.
# =============================================================================

if [ -f ${SENTINEL_FILE} ]; then
  if [ ${DEBUG} -gt 0 ]; then
    echo "Sentinel file ${SENTINEL_FILE} exist. Initialization has already been done."
  fi
  exec ${FINAL_COMMAND}
  exit ${OK}
fi

# =============================================================================
# Initialization that is required only once.
# Usually because attached volume has already been initialized.
# =============================================================================

# -----------------------------------------------------------------------------
# Handle "mysql" protocol.
# -----------------------------------------------------------------------------

if [ "${PROTOCOL}" == "mysql" ]; then

  # Make temporary directory in SENZING_ROOT.

  mkdir -p ${SENZING_ROOT}/tmp

  # Prevent interactivity.

  export DEBIAN_FRONTEND=noninteractive

  # Install libmysqlclient21.

  wget \
    --output-document=${SENZING_ROOT}/tmp/libmysqlclient.deb \
    http://repo.mysql.com/apt/debian/pool/mysql-8.0/m/mysql-community/libmysqlclient21_8.0.16-2debian9_amd64.deb

  dpkg --fsys-tarfile ${SENZING_ROOT}/tmp/libmysqlclient.deb \
    | tar xOf - ./usr/lib/x86_64-linux-gnu/libmysqlclient.so.21.0.16 \
    > ${SENZING_ROOT}/g2/lib/libmysqlclient.so.21.0.16

  ln -s ${SENZING_ROOT}/g2/lib/libmysqlclient.so.21.0.16 ${SENZING_ROOT}/g2/lib/libmysqlclient.so.21

# -----------------------------------------------------------------------------
# Handle "postgresql" protocol.
# -----------------------------------------------------------------------------

elif [ "${PROTOCOL}" == "postgresql" ]; then

  true  # Need a statement in bash if/else

# -----------------------------------------------------------------------------
# Handle "db2" protocol.
# -----------------------------------------------------------------------------

elif [ "${PROTOCOL}" == "db2" ]; then

  mv ${SENZING_ROOT}/db2/clidriver/cfg/db2dsdriver.cfg ${SENZING_ROOT}/db2/clidriver/cfg/db2dsdriver.cfg.original
  cp /opt/IBM/db2/clidriver/cfg/db2dsdriver.cfg.db2-template ${SENZING_ROOT}/db2/clidriver/cfg/db2dsdriver.cfg
  sed -i.$(date +%s) \
    -e "s/{HOST}/${HOST}/g" \
    -e "s/{PORT}/${PORT}/g" \
    -e "s/{SCHEMA}/${SCHEMA}/g" \
    ${SENZING_ROOT}/db2/clidriver/cfg/db2dsdriver.cfg

fi

# -----------------------------------------------------------------------------
# Handle common changes.
# -----------------------------------------------------------------------------

sed -i.$(date +%s) \
  -e "s|G2Connection=sqlite3://na:na@${SENZING_ROOT}/g2/sqldb/G2C.db|G2Connection=${NEW_SENZING_DATABASE_URL}|g" \
  ${SENZING_ROOT}/g2/python/G2Project.ini

sed -i.$(date +%s) \
  -e "s|CONNECTION=sqlite3://na:na@${SENZING_ROOT}/g2/sqldb/G2C.db|CONNECTION=${NEW_SENZING_DATABASE_URL}|g" \
  ${SENZING_ROOT}/g2/python/G2Module.ini

if [ ${DEBUG} -gt 0 ]; then
  echo "---------- g2/python/G2Project.ini --------------------------------------------"
  cat ${SENZING_ROOT}/g2/python/G2Project.ini
  echo "---------- g2/python/G2Module.ini ---------------------------------------------"
  cat ${SENZING_ROOT}/g2/python/G2Module.ini
  echo "---------- ${SENZING_ROOT}/db2/clidriver/cfg/db2dsdriver.cfg -------------------------"
  cat ${SENZING_ROOT}/db2/clidriver/cfg/db2dsdriver.cfg
  echo "-------------------------------------------------------------------------------"
fi

# -----------------------------------------------------------------------------
# Epilog
# -----------------------------------------------------------------------------

# Append to a "sentinel file" to indicate when this script has been run.
# The sentinel file is used to identify the first run from subsequent runs for "first-time" processing.

echo "$(date) ${PROTOCOL}" >> ${SENTINEL_FILE}

# Run the command specified by the parameters.

exec ${FINAL_COMMAND}
