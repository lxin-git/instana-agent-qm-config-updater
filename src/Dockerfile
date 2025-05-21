# Use Red Hat UBI images for OpenShift compatibility
FROM registry.access.redhat.com/ubi8/ubi-minimal:latest

# Install tools: bash, curl, jq, yq（Go Version）and kubectl
RUN microdnf update -y && \
    microdnf install -y bash curl jq tar gzip && \
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && mv kubectl /usr/local/bin/ && \
    curl -L https://github.com/mikefarah/yq/releases/download/v4.45.4/yq_linux_amd64 -o /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq && \
    microdnf clean all