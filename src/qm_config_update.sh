#!/bin/bash

_TMP_DIR="/tmp/instana"
mkdir -p $_TMP_DIR

# Global Setting for qm connection
_POLL_RATE=60
_CHANNEL="INSTANA.A.SVRCONN"
_KEYSTOREPASSWORD="passw0rd"
_KEYSTORE="/opt/instana/agent/etc/qmgrs-keystore.jks"
_CIPHERSUITE="TLS_AES_256_GCM_SHA384"

# Get current queue maanger list
mapfile -t qm_list < <(kubectl get queuemanagers.mq.ibm.com -A -o jsonpath='{range .items[*]}{.spec.queueManager.name}{"\n"}{end}')


# Generate new instana agent config for ibmmq
if [ ${#qm_list[@]} -eq 0 ]; then
  echo "No Queue Manager found, Disable the ibmmq plugin."
  ibmmq_config="com.instana.plugin.ibmmq:\n  enabled: false"
else
  ibmmq_config="com.instana.plugin.ibmmq:
    enabled: true
    poll_rate: ${_POLL_RATE}
    queueManagers:"

  for qm in "${qm_list[@]}"; do
    ibmmq_config+="
      ${qm}:
        channel: ${_CHANNEL}
        keystorePassword: '${_KEYSTOREPASSWORD}'
        keystore: '${_KEYSTORE}'
        cipherSuite: $_CIPHERSUITE"
  done
fi
echo "$ibmmq_config" > ${_TMP_DIR}/ibmmq_config.yaml

# Get current instana agent configuration_yaml content
kubectl get agents.instana.io instana-agent -n instana-agent -o jsonpath='{.spec.agent.configuration_yaml}' > ${_TMP_DIR}/current_config.yaml

# Merge configuration_yaml content (delete old com.instana.plugin.ibmmq and merge new)
merged_config=$(yq eval-all '(select(fileIndex==0) | del(."com.instana.plugin.ibmmq")) * (select(fileIndex==1) | .)' ${_TMP_DIR}/current_config.yaml ${_TMP_DIR}/ibmmq_config.yaml)
echo "$merged_config" > ${_TMP_DIR}/merged_config.yaml

# Patch the instana agent CR to update the change
kubectl patch agents.instana.io instana-agent -n instana-agent --type=merge --patch="{\"spec\":{\"agent\":{\"configuration_yaml\":$(jq -n --arg conf "$merged_config" '$conf')}}}"

echo "The following new com.instana.plugin.ibmmq config has been updated to Instana agent:"
cat ${_TMP_DIR}/merged_config.yaml