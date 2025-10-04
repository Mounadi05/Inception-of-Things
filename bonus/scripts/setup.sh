#!/bin/bash

# ==============================================================================
# MASTER SETUP SCRIPT
# This script executes the following stages sequentially:
#   1. Sets up the GitLab Docker container and saves initial ENV.
#   2. Configures the GitLab project, pushes the app, and gets the PAT.
#   3. Sets up the K3d cluster and deploys Argo CD with the configured Git repo.
# ==============================================================================

set -e

SCRIPT_GITLAB="./setup_gitlab.sh"
SCRIPT_GITLAB_REPO="./setup_gitlab_repo.sh"
SCRIPT_K3D="./setup_k3d.sh"

echo "----------------------------------------------------------"
echo "STAGE 1: Executing $SCRIPT_GITLAB (GitLab Docker & Initial ENV)"
echo "----------------------------------------------------------"

chmod +x "$SCRIPT_GITLAB"
"$SCRIPT_GITLAB"

echo ""
echo "----------------------------------------------------------"
echo "STAGE 2: Executing $SCRIPT_GITLAB_REPO (Project, SSH Key, PAT)"
echo "----------------------------------------------------------"

chmod +x "$SCRIPT_GITLAB_REPO"
"$SCRIPT_GITLAB_REPO"



echo ""
echo "----------------------------------------------------------"
echo "STAGE 3: Executing $SCRIPT_K3D (K3d Cluster & Argo CD Deployment)"
echo "----------------------------------------------------------"

chmod +x "$SCRIPT_K3D"
"$SCRIPT_K3D"

