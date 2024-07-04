#!/bin/bash

# Update package list and install necessary dependencies
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y curl gnupg bash git jq build-essential python3-dev libffi-dev npm make

# Install Node.js and npm
curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install nodemon globally
sudo npm install -g nodemon

# Install k6
curl -sLO https://github.com/grafana/k6/releases/download/v0.34.1/k6-v0.34.1-linux-amd64.tar.gz
tar -xzf k6-v0.34.1-linux-amd64.tar.gz
sudo mv k6-v0.34.1-linux-amd64/k6 /usr/local/bin/k6
rm -rf k6-v0.34.1-linux-amd64*

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl

# Install gcloud SDK
curl -sSL https://sdk.cloud.google.com | bash
exec -l $SHELL

# Add gcloud to PATH
echo "export PATH=\$PATH:/home/$USER/google-cloud-sdk/bin" >> ~/.bashrc
source ~/.bashrc

# Install gcloud components
gcloud components install kubectl gke-gcloud-auth-plugin --quiet

# Clone your repository (replace with your repository URL)
git clone https://github.com/antrein/k6-testing.git
cd k6-testing

# Install Node.js dependencies
npm install

# Make shell scripts executable
chmod +x run-scenario.sh
chmod +x get-cluster/gcp.sh
chmod +x prometheus.sh

# Start the node server using nodemon
nodemon test-scenario.js &