#!/usr/bin/env bash
set -euo pipefail

cd /opt/smile-quest
if [[ -e deploy/data.env ]]; then
  echo 'data.env already exists; leaving it unchanged'
  exit 0
fi

umask 077
cat >deploy/data.env <<EOF
POSTGRES_PASSWORD=$(openssl rand -hex 32)
PHOTO_SIGNING_KEY=$(openssl rand -hex 32)
DATA_PRIVATE_IP=192.168.0.2
EXERCISE_PRIVATE_IP=192.168.0.3
API_DOMAIN=api.invalid
EXERCISE_DOMAIN=exercise.invalid
EOF
chmod 600 deploy/data.env
echo 'Created private data.env'
