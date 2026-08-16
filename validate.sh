#!/usr/bin/env bash

# Read-only validation for Azure Secure Storage Capstone.

set -u
set -o pipefail

PROJECT_ENV_FILE="${PWD}/stc-project.env"
[[ -f "$PROJECT_ENV_FILE" ]] || {
  printf '[FAIL] %s was not found. Run deploy.sh from this directory first.\n' "$PROJECT_ENV_FILE" >&2
  exit 1
}

# shellcheck disable=SC1090
source "$PROJECT_ENV_FILE"

section() { printf '\n=== %s ===\n' "$*"; }

section "Resource inventory"
az resource list \
  --resource-group "$PROJECT_RG" \
  --query "[].{Name:name,Type:type,Location:location}" \
  --output table

section "Primary Storage security"
az storage account show \
  --resource-group "$PROJECT_RG" \
  --name "$PROJECT_PRIMARY_STORAGE" \
  --query "{Name:name,HTTPS:enableHttpsTrafficOnly,MinimumTLS:minimumTlsVersion,PublicBlobAccess:allowBlobPublicAccess,DefaultNetworkAction:networkRuleSet.defaultAction,Identity:identity.type}" \
  --output table

section "Blob protection"
az storage account blob-service-properties show \
  --resource-group "$PROJECT_RG" \
  --account-name "$PROJECT_PRIMARY_STORAGE" \
  --query "{Versioning:isVersioningEnabled,ChangeFeed:changeFeed.enabled,BlobSoftDelete:deleteRetentionPolicy.enabled,BlobRetentionDays:deleteRetentionPolicy.days,ContainerSoftDelete:containerDeleteRetentionPolicy.enabled,PITR:restorePolicy.enabled}" \
  --output table

section "Encryption scopes"
az storage account encryption-scope list \
  --resource-group "$PROJECT_RG" \
  --account-name "$PROJECT_PRIMARY_STORAGE" \
  --query "[].{Name:name,KeySource:keySource,State:state}" \
  --output table

section "Lifecycle management"
az storage account management-policy show \
  --resource-group "$PROJECT_RG" \
  --account-name "$PROJECT_PRIMARY_STORAGE" \
  --query "policy.rules[].{Name:name,Enabled:enabled,Type:type,Prefix:definition.filters.prefixMatch[0]}" \
  --output table

section "Object replication"
printf 'Source account: %s\n' "$PROJECT_PRIMARY_STORAGE"
az storage account or-policy list \
  --resource-group "$PROJECT_RG" \
  --account-name "$PROJECT_PRIMARY_STORAGE" \
  --query "[].{PolicyId:policyId,Rules:length(rules)}" \
  --output table 2>/dev/null || printf 'Object replication policy is not available.\n'

printf '\nDestination account: %s\n' "$PROJECT_DR_STORAGE"
az storage account or-policy list \
  --resource-group "$PROJECT_RG" \
  --account-name "$PROJECT_DR_STORAGE" \
  --query "[].{PolicyId:policyId,Rules:length(rules)}" \
  --output table 2>/dev/null || printf 'Destination replication policy is not available.\n'

section "Private Endpoint"
if [[ "$PROJECT_PRIVATE_ENDPOINT_STATUS" == "Created" ]]; then
  az network private-endpoint show \
    --resource-group "$PROJECT_RG" \
    --name "$PROJECT_PE" \
    --query "{Name:name,State:privateLinkServiceConnections[0].privateLinkServiceConnectionState.status,PrivateIP:customDnsConfigs[0].ipAddresses[0],Target:privateLinkServiceConnections[0].groupIds[0]}" \
    --output table
else
  printf 'Private Endpoint was not created; Service Endpoint is the fallback.\n'
fi

section "Diagnostic settings"
PROJECT_STORAGE_ID="$(az storage account show \
  --resource-group "$PROJECT_RG" \
  --name "$PROJECT_PRIMARY_STORAGE" \
  --query id \
  --output tsv)"
az monitor diagnostic-settings list \
  --resource "${PROJECT_STORAGE_ID}/blobServices/default" \
  --query "value[].{Name:name,EnabledLogs:length(logs[?enabled]),EnabledMetrics:length(metrics[?enabled])}" \
  --output table 2>/dev/null || printf 'Diagnostic setting is not available.\n'

section "Private DNS validation from VM"
if [[ "$PROJECT_VM_STATUS" == "Created" ]]; then
  az vm run-command invoke \
    --resource-group "$PROJECT_RG" \
    --name "$PROJECT_VM" \
    --command-id RunShellScript \
    --scripts "echo 'DNS resolution:'; getent hosts ${PROJECT_PRIMARY_STORAGE}.blob.core.windows.net; echo 'HTTPS response:'; curl -sS -o /dev/null -w '%{http_code}\\n' https://${PROJECT_PRIMARY_STORAGE}.blob.core.windows.net/" \
    --query "value[0].message" \
    --output tsv
else
  printf 'VM was not created; validate Private DNS from another client in the VNet.\n'
fi

section "Validation complete"
printf 'Capture the eight screenshots listed in screenshot-checklist.md.\n'
