#!/usr/bin/env bash

# Azure Secure Storage Capstone - rapid sandbox deployment
# Designed for a short-lived Pluralsight sandbox. No secrets are written to disk.

set -u
set -o pipefail

PROJECT_START_SECONDS=$SECONDS
PROJECT_PREFIX="stc"
PROJECT_ENV_FILE="${PWD}/stc-project.env"

info() { printf '\n[INFO] %s\n' "$*"; }
ok() { printf '[OK]   %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*" >&2; }
fatal() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

required() {
  local label="$1"
  shift
  info "$label"
  if "$@" >/dev/null; then
    ok "$label"
  else
    fatal "$label"
  fi
}

optional() {
  local label="$1"
  shift
  info "$label"
  if "$@" >/dev/null; then
    ok "$label"
    return 0
  fi
  warn "$label failed; continuing with the fallback design."
  return 1
}

command -v az >/dev/null 2>&1 || fatal "Azure CLI is not available. Run this script in Azure Cloud Shell (Bash)."
az account show >/dev/null 2>&1 || fatal "No active Azure login was found."

if [[ -n "${AZURE_RG:-}" ]]; then
  PROJECT_RG="$AZURE_RG"
else
  mapfile -t PROJECT_GROUPS < <(az group list --query "[].name" --output tsv)
  ((${#PROJECT_GROUPS[@]} > 0)) || fatal "No accessible resource group was found."
  if ((${#PROJECT_GROUPS[@]} > 1)); then
    printf '\nAccessible resource groups:\n'
    printf '  %s\n' "${PROJECT_GROUPS[@]}"
    fatal "More than one resource group exists. Run: export AZURE_RG='<resource-group>'; bash deploy.sh"
  fi
  PROJECT_RG="${PROJECT_GROUPS[0]}"
fi

PROJECT_LOCATION="${AZURE_LOCATION:-$(az group show --name "$PROJECT_RG" --query location --output tsv)}"
[[ -n "$PROJECT_LOCATION" ]] || fatal "Could not determine the deployment region."

case "$PROJECT_LOCATION" in
  eastus) PROJECT_DESIRED_DR_LOCATION="westus2" ;;
  westus2) PROJECT_DESIRED_DR_LOCATION="eastus" ;;
  centralus) PROJECT_DESIRED_DR_LOCATION="eastus2" ;;
  eastus2) PROJECT_DESIRED_DR_LOCATION="centralus" ;;
  westeurope) PROJECT_DESIRED_DR_LOCATION="northeurope" ;;
  northeurope) PROJECT_DESIRED_DR_LOCATION="westeurope" ;;
  uksouth) PROJECT_DESIRED_DR_LOCATION="ukwest" ;;
  southeastasia) PROJECT_DESIRED_DR_LOCATION="eastasia" ;;
  *) PROJECT_DESIRED_DR_LOCATION="$PROJECT_LOCATION" ;;
esac
PROJECT_DR_LOCATION="${AZURE_DR_LOCATION:-$PROJECT_DESIRED_DR_LOCATION}"

PROJECT_CHECKSUM="$(printf '%s' "$PROJECT_RG" | cksum | awk '{print $1}')"
PROJECT_SUFFIX="$(printf '%06d' "$((PROJECT_CHECKSUM % 1000000))")"

PROJECT_VNET="vnet-${PROJECT_PREFIX}-storage"
PROJECT_CLIENT_SUBNET="snet-client"
PROJECT_PE_SUBNET="snet-private-endpoint"
PROJECT_VM="vm-${PROJECT_PREFIX}-storage-client"
PROJECT_PRIMARY_STORAGE="${PROJECT_PREFIX}src${PROJECT_SUFFIX}"
PROJECT_DR_STORAGE="${PROJECT_PREFIX}dr${PROJECT_SUFFIX}"
PROJECT_LAW="law-${PROJECT_PREFIX}-storage"
PROJECT_PE="pe-${PROJECT_PREFIX}-blob"
PROJECT_DNS_ZONE="privatelink.blob.core.windows.net"
PROJECT_DNS_LINK="link-${PROJECT_PREFIX}-storage"
PROJECT_DNS_GROUP="zonegroup-${PROJECT_PREFIX}-blob"

printf '\n=== Azure Secure Storage Capstone ===\n'
printf 'Resource group : %s\n' "$PROJECT_RG"
printf 'Primary region : %s\n' "$PROJECT_LOCATION"
printf 'Desired DR     : %s\n' "$PROJECT_DR_LOCATION"
printf 'Primary storage: %s\n' "$PROJECT_PRIMARY_STORAGE"
printf 'DR storage     : %s\n' "$PROJECT_DR_STORAGE"

info "Creating virtual network and subnets"
required "Create VNet and client subnet" \
  az network vnet create \
    --resource-group "$PROJECT_RG" \
    --location "$PROJECT_LOCATION" \
    --name "$PROJECT_VNET" \
    --address-prefixes 10.40.0.0/16 \
    --subnet-name "$PROJECT_CLIENT_SUBNET" \
    --subnet-prefixes 10.40.1.0/24

required "Enable Microsoft.Storage service endpoint" \
  az network vnet subnet update \
    --resource-group "$PROJECT_RG" \
    --vnet-name "$PROJECT_VNET" \
    --name "$PROJECT_CLIENT_SUBNET" \
    --service-endpoints Microsoft.Storage

required "Create private endpoint subnet" \
  az network vnet subnet create \
    --resource-group "$PROJECT_RG" \
    --vnet-name "$PROJECT_VNET" \
    --name "$PROJECT_PE_SUBNET" \
    --address-prefixes 10.40.2.0/24

required "Create primary StorageV2 account" \
  az storage account create \
    --resource-group "$PROJECT_RG" \
    --location "$PROJECT_LOCATION" \
    --name "$PROJECT_PRIMARY_STORAGE" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --https-only true \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --allow-cross-tenant-replication false \
    --tags project=Azure-Secure-Storage-Capstone environment=Sandbox owner=Sohrab

info "Creating DR StorageV2 account in $PROJECT_DR_LOCATION"
if ! az storage account create \
    --resource-group "$PROJECT_RG" \
    --location "$PROJECT_DR_LOCATION" \
    --name "$PROJECT_DR_STORAGE" \
    --sku Standard_LRS \
    --kind StorageV2 \
    --https-only true \
    --min-tls-version TLS1_2 \
    --allow-blob-public-access false \
    --allow-cross-tenant-replication false \
    --tags project=Azure-Secure-Storage-Capstone environment=DR owner=Sohrab \
    >/dev/null; then
  warn "The sandbox rejected the second region. Retrying DR in $PROJECT_LOCATION."
  PROJECT_DR_LOCATION="$PROJECT_LOCATION"
  required "Create DR StorageV2 account in fallback region" \
    az storage account create \
      --resource-group "$PROJECT_RG" \
      --location "$PROJECT_DR_LOCATION" \
      --name "$PROJECT_DR_STORAGE" \
      --sku Standard_LRS \
      --kind StorageV2 \
      --https-only true \
      --min-tls-version TLS1_2 \
      --allow-blob-public-access false \
      --allow-cross-tenant-replication false \
      --tags project=Azure-Secure-Storage-Capstone environment=DR owner=Sohrab
else
  ok "Create DR StorageV2 account in second region"
fi

optional "Enable system-assigned identity on primary storage" \
  az storage account update \
    --resource-group "$PROJECT_RG" \
    --name "$PROJECT_PRIMARY_STORAGE" \
    --assign-identity

info "Creating encryption scope and data containers"
required "Create Microsoft-managed finance encryption scope" \
  az storage account encryption-scope create \
    --resource-group "$PROJECT_RG" \
    --account-name "$PROJECT_PRIMARY_STORAGE" \
    --name finance-scope \
    --key-source Microsoft.Storage

required "Create finance container with enforced encryption scope" \
  az storage container create \
    --account-name "$PROJECT_PRIMARY_STORAGE" \
    --name finance \
    --public-access off \
    --default-encryption-scope finance-scope \
    --prevent-encryption-scope-override true \
    --auth-mode key

for PROJECT_CONTAINER in logs contractor replication-source; do
  required "Create private container: $PROJECT_CONTAINER" \
    az storage container create \
      --account-name "$PROJECT_PRIMARY_STORAGE" \
      --name "$PROJECT_CONTAINER" \
      --public-access off \
      --auth-mode key
done

required "Create destination replication container" \
  az storage container create \
    --account-name "$PROJECT_DR_STORAGE" \
    --name replica \
    --public-access off \
    --auth-mode key

required "Create Azure Files operations share" \
  az storage share create \
    --account-name "$PROJECT_PRIMARY_STORAGE" \
    --name operations \
    --quota 100

PROJECT_TMP_DIR="/tmp/stc-storage-capstone-${PROJECT_SUFFIX}"
mkdir -p "$PROJECT_TMP_DIR"
printf 'STC Finance Report - protected by finance-scope\n' >"$PROJECT_TMP_DIR/finance-report.txt"
printf 'STC operational file share validation\n' >"$PROJECT_TMP_DIR/operations-readme.txt"
printf 'STC contractor read-only SAS validation\n' >"$PROJECT_TMP_DIR/contractor-guide.txt"
printf 'STC asynchronous object replication validation\n' >"$PROJECT_TMP_DIR/replication-test.txt"

required "Upload encrypted finance test blob" \
  az storage blob upload \
    --account-name "$PROJECT_PRIMARY_STORAGE" \
    --container-name finance \
    --name finance-report.txt \
    --file "$PROJECT_TMP_DIR/finance-report.txt" \
    --overwrite true \
    --auth-mode key

required "Upload contractor test blob" \
  az storage blob upload \
    --account-name "$PROJECT_PRIMARY_STORAGE" \
    --container-name contractor \
    --name contractor-guide.txt \
    --file "$PROJECT_TMP_DIR/contractor-guide.txt" \
    --overwrite true \
    --auth-mode key

required "Upload Azure Files test file" \
  az storage file upload \
    --account-name "$PROJECT_PRIMARY_STORAGE" \
    --share-name operations \
    --source "$PROJECT_TMP_DIR/operations-readme.txt" \
    --path operations-readme.txt

optional "Create Azure Files share snapshot" \
  az storage share snapshot \
    --account-name "$PROJECT_PRIMARY_STORAGE" \
    --name operations

info "Creating stored access policy and validating a policy-bound Service SAS"
PROJECT_SAS_START="$(date -u -d '5 minutes ago' '+%Y-%m-%dT%H:%MZ')"
PROJECT_SAS_EXPIRY="$(date -u -d '2 hours' '+%Y-%m-%dT%H:%MZ')"
required "Create contractor read-only stored access policy" \
  az storage container policy create \
    --account-name "$PROJECT_PRIMARY_STORAGE" \
    --container-name contractor \
    --name contractor-read-policy \
    --permissions rl \
    --start "$PROJECT_SAS_START" \
    --expiry "$PROJECT_SAS_EXPIRY" \
    --auth-mode key

PROJECT_SAS_TOKEN="$(az storage container generate-sas \
  --account-name "$PROJECT_PRIMARY_STORAGE" \
  --name contractor \
  --policy-name contractor-read-policy \
  --https-only \
  --auth-mode key \
  --output tsv 2>/dev/null || true)"
if [[ -n "$PROJECT_SAS_TOKEN" ]] && az storage blob list \
    --account-name "$PROJECT_PRIMARY_STORAGE" \
    --container-name contractor \
    --sas-token "$PROJECT_SAS_TOKEN" \
    --query "[].name" \
    --output tsv \
    >/dev/null; then
  ok "Policy-bound Service SAS read/list validation"
else
  warn "SAS validation failed; the stored access policy still exists for Portal validation."
fi
unset PROJECT_SAS_TOKEN

info "Enabling blob protection features"
required "Enable versioning, change feed, and soft delete on primary" \
  az storage account blob-service-properties update \
    --resource-group "$PROJECT_RG" \
    --account-name "$PROJECT_PRIMARY_STORAGE" \
    --enable-versioning true \
    --enable-change-feed true \
    --enable-delete-retention true \
    --delete-retention-days 14 \
    --enable-container-delete-retention true \
    --container-delete-retention-days 14

required "Enable versioning on DR account" \
  az storage account blob-service-properties update \
    --resource-group "$PROJECT_RG" \
    --account-name "$PROJECT_DR_STORAGE" \
    --enable-versioning true

optional "Enable point-in-time restore for seven days" \
  az storage account blob-service-properties update \
    --resource-group "$PROJECT_RG" \
    --account-name "$PROJECT_PRIMARY_STORAGE" \
    --enable-restore-policy true \
    --restore-days 7

PROJECT_POLICY_FILE="$PROJECT_TMP_DIR/lifecycle-policy.json"
cat >"$PROJECT_POLICY_FILE" <<'JSON'
{
  "rules": [
    {
      "enabled": true,
      "name": "logs-cost-optimization",
      "type": "Lifecycle",
      "definition": {
        "actions": {
          "baseBlob": {
            "tierToCool": { "daysAfterModificationGreaterThan": 30 },
            "tierToArchive": { "daysAfterModificationGreaterThan": 180 },
            "delete": { "daysAfterModificationGreaterThan": 365 }
          },
          "version": {
            "delete": { "daysAfterCreationGreaterThan": 90 }
          }
        },
        "filters": {
          "blobTypes": ["blockBlob"],
          "prefixMatch": ["logs/"]
        }
      }
    }
  ]
}
JSON

required "Create lifecycle cost-optimization policy" \
  az storage account management-policy create \
    --resource-group "$PROJECT_RG" \
    --account-name "$PROJECT_PRIMARY_STORAGE" \
    --policy "@$PROJECT_POLICY_FILE"

info "Creating asynchronous object replication policy"
PROJECT_PRIMARY_STORAGE_ID="$(az storage account show \
  --resource-group "$PROJECT_RG" \
  --name "$PROJECT_PRIMARY_STORAGE" \
  --query id \
  --output tsv)"
PROJECT_DR_STORAGE_ID="$(az storage account show \
  --resource-group "$PROJECT_RG" \
  --name "$PROJECT_DR_STORAGE" \
  --query id \
  --output tsv)"
if az storage account or-policy create \
    --resource-group "$PROJECT_RG" \
    --account-name "$PROJECT_DR_STORAGE" \
    --source-account "$PROJECT_PRIMARY_STORAGE_ID" \
    --destination-account "$PROJECT_DR_STORAGE_ID" \
    --source-container replication-source \
    --destination-container replica \
    --enable-metrics true \
    >/dev/null; then
  PROJECT_OR_POLICY_ID="$(az storage account or-policy list \
    --resource-group "$PROJECT_RG" \
    --account-name "$PROJECT_DR_STORAGE" \
    --query '[0].policyId' \
    --output tsv)"
  if [[ -n "$PROJECT_OR_POLICY_ID" ]] && az storage account or-policy show \
      --resource-group "$PROJECT_RG" \
      --account-name "$PROJECT_DR_STORAGE" \
      --policy-id "$PROJECT_OR_POLICY_ID" \
      | az storage account or-policy create \
          --resource-group "$PROJECT_RG" \
          --account-name "$PROJECT_PRIMARY_STORAGE" \
          --policy '@-' \
          >/dev/null; then
    ok "Create matching object replication policies"
    optional "Upload object replication test blob" \
      az storage blob upload \
        --account-name "$PROJECT_PRIMARY_STORAGE" \
        --container-name replication-source \
        --name replication-test.txt \
        --file "$PROJECT_TMP_DIR/replication-test.txt" \
        --overwrite true \
        --auth-mode key
  else
    warn "Destination policy exists, but the source policy association failed."
  fi
else
  warn "Object replication policy failed; continue and capture the error as a sandbox limitation."
  PROJECT_OR_POLICY_ID=""
fi

info "Creating Log Analytics workspace and Blob diagnostic settings"
if optional "Create Log Analytics workspace" \
    az monitor log-analytics workspace create \
      --resource-group "$PROJECT_RG" \
      --location "$PROJECT_LOCATION" \
      --workspace-name "$PROJECT_LAW" \
      --tags project=Azure-Secure-Storage-Capstone owner=Sohrab; then
  PROJECT_LAW_ID="$(az monitor log-analytics workspace show \
    --resource-group "$PROJECT_RG" \
    --workspace-name "$PROJECT_LAW" \
    --query id \
    --output tsv)"
  PROJECT_STORAGE_ID="$(az storage account show \
    --resource-group "$PROJECT_RG" \
    --name "$PROJECT_PRIMARY_STORAGE" \
    --query id \
    --output tsv)"
  PROJECT_BLOB_SERVICE_ID="${PROJECT_STORAGE_ID}/blobServices/default"
  optional "Send Blob logs and transaction metrics to Log Analytics" \
    az monitor diagnostic-settings create \
      --name diag-blob-to-law \
      --resource "$PROJECT_BLOB_SERVICE_ID" \
      --workspace "$PROJECT_LAW_ID" \
      --logs '[{"category":"StorageRead","enabled":true},{"category":"StorageWrite","enabled":true},{"category":"StorageDelete","enabled":true}]' \
      --metrics '[{"category":"Transaction","enabled":true}]'
fi

info "Creating a private Blob endpoint and private DNS integration"
PROJECT_STORAGE_ID="$(az storage account show \
  --resource-group "$PROJECT_RG" \
  --name "$PROJECT_PRIMARY_STORAGE" \
  --query id \
  --output tsv)"
PROJECT_PE_SUBNET_ID="$(az network vnet subnet show \
  --resource-group "$PROJECT_RG" \
  --vnet-name "$PROJECT_VNET" \
  --name "$PROJECT_PE_SUBNET" \
  --query id \
  --output tsv)"

PROJECT_PRIVATE_ENDPOINT_STATUS="Failed"
if az network private-endpoint create \
    --resource-group "$PROJECT_RG" \
    --location "$PROJECT_LOCATION" \
    --name "$PROJECT_PE" \
    --subnet "$PROJECT_PE_SUBNET_ID" \
    --private-connection-resource-id "$PROJECT_STORAGE_ID" \
    --group-id blob \
    --connection-name "conn-${PROJECT_PREFIX}-blob" \
    >/dev/null; then
  PROJECT_PRIVATE_ENDPOINT_STATUS="Created"
  ok "Create Blob private endpoint"
  if optional "Create Blob private DNS zone" \
      az network private-dns zone create \
        --resource-group "$PROJECT_RG" \
        --name "$PROJECT_DNS_ZONE"; then
    optional "Link private DNS zone to VNet" \
      az network private-dns link vnet create \
        --resource-group "$PROJECT_RG" \
        --zone-name "$PROJECT_DNS_ZONE" \
        --name "$PROJECT_DNS_LINK" \
        --virtual-network "$PROJECT_VNET" \
        --registration-enabled false
    optional "Attach private DNS zone group to endpoint" \
      az network private-endpoint dns-zone-group create \
        --resource-group "$PROJECT_RG" \
        --endpoint-name "$PROJECT_PE" \
        --name "$PROJECT_DNS_GROUP" \
        --private-dns-zone "$PROJECT_DNS_ZONE" \
        --zone-name blob
  fi
else
  warn "Private Endpoint was rejected. Service Endpoint remains available as the fallback."
fi

info "Creating a private Linux validation VM (no public IP)"
PROJECT_VM_STATUS="Failed"
if az vm create \
    --resource-group "$PROJECT_RG" \
    --location "$PROJECT_LOCATION" \
    --name "$PROJECT_VM" \
    --image Ubuntu2204 \
    --size Standard_B1s \
    --admin-username azureuser \
    --generate-ssh-keys \
    --vnet-name "$PROJECT_VNET" \
    --subnet "$PROJECT_CLIENT_SUBNET" \
    --public-ip-address '' \
    --assign-identity \
    --tags project=Azure-Secure-Storage-Capstone role=PrivateValidation owner=Sohrab \
    >/dev/null; then
  PROJECT_VM_STATUS="Created"
  ok "Create private Linux VM with managed identity"
else
  warn "Standard_B1s VM failed. Retrying with Standard_B2s."
  if az vm create \
      --resource-group "$PROJECT_RG" \
      --location "$PROJECT_LOCATION" \
      --name "$PROJECT_VM" \
      --image Ubuntu2204 \
      --size Standard_B2s \
      --admin-username azureuser \
      --generate-ssh-keys \
      --vnet-name "$PROJECT_VNET" \
      --subnet "$PROJECT_CLIENT_SUBNET" \
      --public-ip-address '' \
      --assign-identity \
      --tags project=Azure-Secure-Storage-Capstone role=PrivateValidation owner=Sohrab \
      >/dev/null; then
    PROJECT_VM_STATUS="Created"
    ok "Create private Linux VM with fallback size"
  else
    warn "VM deployment failed; use Portal screenshots and Private Endpoint state for validation."
  fi
fi

info "Applying Storage firewall rules after data-plane configuration"
optional "Allow client subnet through Storage firewall" \
  az storage account network-rule add \
    --resource-group "$PROJECT_RG" \
    --account-name "$PROJECT_PRIMARY_STORAGE" \
    --vnet-name "$PROJECT_VNET" \
    --subnet "$PROJECT_CLIENT_SUBNET"

optional "Set primary Storage firewall default action to Deny" \
  az storage account update \
    --resource-group "$PROJECT_RG" \
    --name "$PROJECT_PRIMARY_STORAGE" \
    --public-network-access Enabled \
    --default-action Deny

optional "Allow trusted Azure services through the Storage firewall" \
  az storage account update \
    --resource-group "$PROJECT_RG" \
    --name "$PROJECT_PRIMARY_STORAGE" \
    --bypass AzureServices

cat >"$PROJECT_ENV_FILE" <<EOF
PROJECT_RG='$PROJECT_RG'
PROJECT_LOCATION='$PROJECT_LOCATION'
PROJECT_DR_LOCATION='$PROJECT_DR_LOCATION'
PROJECT_PRIMARY_STORAGE='$PROJECT_PRIMARY_STORAGE'
PROJECT_DR_STORAGE='$PROJECT_DR_STORAGE'
PROJECT_VNET='$PROJECT_VNET'
PROJECT_CLIENT_SUBNET='$PROJECT_CLIENT_SUBNET'
PROJECT_PE_SUBNET='$PROJECT_PE_SUBNET'
PROJECT_VM='$PROJECT_VM'
PROJECT_LAW='$PROJECT_LAW'
PROJECT_PE='$PROJECT_PE'
PROJECT_DNS_ZONE='$PROJECT_DNS_ZONE'
PROJECT_PRIVATE_ENDPOINT_STATUS='$PROJECT_PRIVATE_ENDPOINT_STATUS'
PROJECT_VM_STATUS='$PROJECT_VM_STATUS'
PROJECT_OR_POLICY_ID='${PROJECT_OR_POLICY_ID:-}'
EOF

PROJECT_ELAPSED="$((SECONDS - PROJECT_START_SECONDS))"
printf '\n=== Deployment summary ===\n'
printf 'Primary storage      : %s (%s)\n' "$PROJECT_PRIMARY_STORAGE" "$PROJECT_LOCATION"
printf 'DR storage           : %s (%s)\n' "$PROJECT_DR_STORAGE" "$PROJECT_DR_LOCATION"
printf 'Private Endpoint     : %s\n' "$PROJECT_PRIVATE_ENDPOINT_STATUS"
printf 'Private validation VM: %s\n' "$PROJECT_VM_STATUS"
printf 'Environment file     : %s\n' "$PROJECT_ENV_FILE"
printf 'Elapsed time         : %s seconds\n' "$PROJECT_ELAPSED"
printf '\nNext command: bash validate.sh\n'
