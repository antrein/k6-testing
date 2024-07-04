# Use the official Node.js Alpine image as the base image
FROM node:14-alpine

# Set the working directory inside the container
WORKDIR /usr/src/app

# Install dependencies needed for kubectl, gcloud, and jq
RUN apk add --no-cache curl gnupg bash git busybox jq

RUN apk add --no-cache --virtual .pynacl_deps build-base python3-dev libffi-dev

# Install k6 from the official release
RUN curl -sLO https://github.com/grafana/k6/releases/download/v0.34.1/k6-v0.34.1-linux-amd64.tar.gz \
    && tar -xzf k6-v0.34.1-linux-amd64.tar.gz \
    && mv k6-v0.34.1-linux-amd64/k6 /usr/local/bin/k6 \
    && rm -rf k6-v0.34.1-linux-amd64* 

# Install kubectl
RUN curl -sLO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl \
    && rm kubectl

# Install gcloud SDK
RUN curl -sSL https://sdk.cloud.google.com | bash > /dev/null

# Add gcloud to PATH
ENV PATH $PATH:/root/google-cloud-sdk/bin

# Install kubectl and gke-gcloud-auth-plugin
RUN gcloud components install kubectl gke-gcloud-auth-plugin --quiet

# Copy package.json and package-lock.json (if available) into the working directory
COPY package*.json ./

# Install the dependencies
RUN npm install

# Copy the rest of the application code into the working directory
COPY . .

# Make the shell scripts executable
RUN chmod +x run-scenario.sh
RUN chmod +x get-cluster/gcp.sh
RUN chmod +x prometheus.sh

# Expose the port your app runs on
EXPOSE 3001

# Start the node server
CMD ["node", "test-scenario.js"]
