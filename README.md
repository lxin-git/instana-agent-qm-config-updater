# instana-agent-qm-config-updater  
Automated configuration updater for Instana agent in Kubernetes/OpenShift clusters to monitor IBM MQ queue managers

## Description

This toolkit demonstrates how to automatically update Instana agent configurations in Kubernetes/OpenShift clusters for IBM MQ queue manager monitoring. It addresses the limitation where [Instana's MQ sensor](https://www.ibm.com/docs/en/instana-observability/current?topic=technologies-monitoring-mq) cannot auto-discover queue managers when running in client binding mode within the same cluster.

## Prerequisites
- Kubernetes/OpenShift cluster with IBM MQ deployments
- Instana agent installed in the cluster
- `kubectl` access to the cluster

## Assumptions
1. All queue managers use identical connection parameters:
   - Connection channel
   - Keystore credentials
   - Cipher suite
2. Instana agent deployed in `instana-agent` namespace

## Mechanism
1. **Discovery**: Script identifies existing queue managers via Kubernetes API
2. **Configuration Generation**: Creates MQ sensor configuration with:
   - Global connection parameters
   - Per-queue-manager endpoints
3. **Merges configuration**: Update instana agent configuration yaml to merge the new mq sensor config.

All the above procedues are hot loaded and don't require an agent rolling restart.

## Setup Instructions

### 1. Clone Repository
```bash
git clone https://github.com/lxin-git/instana-agent-qm-config-updater
cd instana-agent-qm-config-updater/src
```

### 2. Configure Parameters

Edit `qm_config_update.sh` with your connection settings, eg:
```bash
# Global connection parameters
_POLL_RATE=60
_CHANNEL="INSTANA.A.SVRCONN"
_KEYSTOREPASSWORD="passw0rd"
_KEYSTORE="/opt/instana/agent/etc/qmgrs-keystore.jks"
_CIPHERSUITE="TLS_AES_256_GCM_SHA384"
```

### 3-1. Option 1: Manual Configuration Update

After you have any queue manager instance change(add/delete), you can run the script manually to update Instana agent configuration:

Login to your k8s/openshift cluster.
```
./qm_config_update.sh
```
Or you can embend this script execution into your automation pipeline during queue manager updates. It's up to you how you want to implement.

### 3-2. Option 2: Automated Updates (CronJob)

With this option, the cronjob will be created and scan the queue manager instances within the cluster every 5 minutes, then update the Instana agent configuration if any changes detected. 
(As we're using `kubectl patch` on agent CR, no update will be executed if configuration is same with last check)

#### a. Build Docker Image
```bash
docker build -t kube-config-updater:1.0.0 .
docker tag kube-config-updater:1.0.0 <your-registry>/kube-config-updater:1.0.0
docker push <your-registry>/kube-config-updater:1.0.0
```

#### b. Create Kubernetes Resources

```bash
# Create ConfigMap
kubectl -n instana-agent create configmap qm-config-update-sh --from-file=qm_config_update.sh=./qm_config_update.sh

# Apply RBAC configuration
kubectl apply -f sa-roles.yaml

# Deploy CronJob (runs every 5 minutes)
export IMAGE="<your-registry>/kube-config-updater:1.0.0"
cat cronjob.yaml | sed "s|IMAGE_PLACEHOLDER|${IMAGE}|g" | kubectl apply -f -
```

You can test executing the job manually after cronjob creation:
```bash
kubectl create job --from=cronjob/instana-agent-qm-config-updater test-run -n instana-agent
kubectl logs job/test-run -n instana-agent
```


## Disclaimer
This tool has only been tested for functional verification and does not mean it is completely suitable for your environment. This is just a prototype verification to illustrate the feasibility of the workaround. If you need to use it in your production environment, you need to complete the relevant modifications and adjustments by yourself, and test it by yourself or incorporate it into your automation pipeline.
The code in the repo is for reference only and no technical support is provided.