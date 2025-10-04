#!/bin/bash

# ==============================================================================
# GitLab Project & Argo CD Token Automation Script
#
# This script runs after GitLab is installed and does the following:
#   2. Creates a new project using the GitLab API.
#   3. Generates an SSH key and adds it as a Deploy Key to the project.
#   4. Pushes a local directory to the new project repository.
#   5. Creates a new, dedicated Personal Access Token for Argo CD to use.
# ==============================================================================

set -e

PROJECT_NAME="amounadi"
ARGO_CD_TOKEN_NAME="argo_cd"
LOCAL_REPO_DIR="./myapp"
APP_DEPLOY_DIR="../config/app1"
ENV_FILE="./.env"

source $ENV_FILE

echo "[*] Waiting for GitLab application to be fully ready at ${GITLAB_URL}..."

GITLAB_HEALTH_URL="${GITLAB_URL}/users/sign_in" 
RETRY_COUNT=0

until curl --silent --head --fail "${GITLAB_HEALTH_URL}" > /dev/null; do
    if [ $RETRY_COUNT -ge 10 ]; then
        echo "FATAL: GitLab did not become ready within the time limit. Exiting."
        exit 1
    fi
    echo "  [.] GitLab not ready yet (Attempt $RETRY_COUNT). Waiting 30 seconds..."
    sleep 30
    RETRY_COUNT=$((RETRY_COUNT + 1))
done

echo "✅ GitLab container is now running and reachable!"


# 2.crate token-gitlab
TOKEN_GITLAB=`docker exec gitlab gitlab-rails runner "token = User.find(1).personal_access_tokens.create(scopes: [:api], name: 'argo_cd', expires_at: 30.days.from_now); puts token.token"`


echo "------------------------------------------------------------------"
echo "                    CREATING AND ADDING DEPLOY KEY"
echo "------------------------------------------------------------------"

SSH_KEY_PATH="$(pwd)/gitlab_deploy_key"

# Generate a new SSH key without a passphrase
ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" -N "" > /dev/null
PUBLIC_KEY=$(cat "${SSH_KEY_PATH}.pub")

echo ""
echo "✅ SSH Key generated."
echo ""

# Add the public key as a Deploy Key to the project
PROJECT_ID=$(curl --silent --request POST --header "PRIVATE-TOKEN: ${TOKEN_GITLAB}" --data "name=${PROJECT_NAME}" \
  "${GITLAB_URL}/api/v4/projects" | jq -r .id)

echo "✅ SSH Deploy Key generated and added to the project."
echo ""

# Add the public key as a Deploy Key (with push permission)
curl --silent --request POST \
  --header "PRIVATE-TOKEN: ${TOKEN_GITLAB}" \
  --data "title=deploy-key&key=${PUBLIC_KEY}&can_push=true" \
  "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}/deploy_keys" > /dev/null
  
# 4. Push the local directory to the new project repository
echo "------------------------------------------------------------------"
echo "                 PUSHING LOCAL REPO TO GITLAB"
echo "------------------------------------------------------------------"
# Get the SSH URL for the repository from the GitLab API
ssh-keygen -R "[${IP_ADDRESS}]:${PORT_SSH}" 2>/dev/null || true


SSH_URL_REPO=$(curl --silent --header "PRIVATE-TOKEN: ${TOKEN_GITLAB}" "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}" \
  | jq -r .ssh_url_to_repo \
  | sed "s|git@${IP_ADDRESS}:|ssh://git@${IP_ADDRESS}:${PORT_SSH}/|")


echo "ssh_repo :${SSH_URL_REPO}"
# Initialize the local directory as a Git repo
mkdir -p "$LOCAL_REPO_DIR"
cp $APP_DEPLOY_DIR/* $LOCAL_REPO_DIR

cd "$LOCAL_REPO_DIR"
if [ ! -d ".git" ]; then
    git init -b main
    # Create an initial file if the repo is empty to ensure a successful push
    if [ -z "$(ls -A .)" ]; then
        echo "# ${PROJECT_NAME} Repository" > README.md
    fi
    git add .
    git commit -m "Initial commit of local directory"
fi

# Configure git to use the new SSH key and push to the repository
GIT_SSH_COMMAND="ssh -i ${SSH_KEY_PATH} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" git remote set-url origin "${SSH_URL_REPO}" 2>/dev/null || GIT_SSH_COMMAND="ssh -i ${SSH_KEY_PATH} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" git remote add origin "${SSH_URL_REPO}"
GIT_SSH_COMMAND="ssh -i ${SSH_KEY_PATH} -o IdentitiesOnly=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" git push -u origin main

echo ""
echo "✅ local repo pushed to GitLab successfully."
echo ""
cat <<EOF > $ENV_FILE
# GitLab Configuration Saved on $(date)
TOKEN_GITLAB=$TOKEN_GITLAB
GITLAB_USER=root
IP=$IP_ADDRESS
EOF

echo "✅ Configuration successfully updated to $ENV_FILE"
echo ""

echo "✅ Local directory '${LOCAL_REPO_DIR}' successfully pushed to GitLab."
echo ""
echo "Token: ${TOKEN_GITLAB}"
echo ""
echo "GitLab setup complete!"