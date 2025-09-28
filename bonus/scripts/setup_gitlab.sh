#!/bin/bash

set -e

echo ""
echo "🎉 GitLab is starting up! Initialization can take 5-10 minutes."
echo "------------------------------------------------------------------"
echo "                      ✅ EXTRA INFO & NEXT STEPS"
echo "------------------------------------------------------------------"
echo ""

CONFIG=~/gitlab/config
DATA=~/gitlab/data
LOGS=~/gitlab/logs
PORT_HTTP=9080
PORT_SSH=9022
PASSWORD=Amounadi_root_05

mkdir -p  $LOGS
mkdir -p  $DATA
mkdir -p  $CONFIG


IP_ADDRESS=$(hostname -I | awk '{print $1}')

GITLAB_URL=http//:${IP_ADDRESS}:${PORT_HTTP}

docker run --detach  --hostname $IP_ADDRESS --publish $PORT_HTTP:80 --publish $PORT_SSH:22 --publish 443:443 --name gitlab --restart always --volume $CONFIG:/etc/gitlab --volume $LOGS:/var/log/gitlab --volume $DATA:/var/opt/gitlab   --env GITLAB_OMNibus_CONFIG="external_url 'http://${IP_ADDRESS}:${PORT_HTTP}';" gitlab/gitlab-ee:latest


echo "[*] Waiting for GitLab application to be fully ready at ${GITLAB_URL}..."

sleep 120

echo "✅ GitLab container is now running!"

PASSWORD=`docker exec gitlab grep 'Password:' /etc/gitlab/initial_root_password`



echo ""
echo "🌐 ACCESS URL:"
echo "   You can access your GitLab instance at: http://${IP_ADDRESS}:${PORT_HTTP}"
echo ""
echo "👤 ROOT USER PASSWORD: $PASSWORD"





