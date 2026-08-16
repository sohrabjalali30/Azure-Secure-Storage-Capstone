# Azure Secure Storage Capstone — Screenshot Checklist

Capture only these eight screenshots before the sandbox expires. Never expose an access key, connection string, SAS signature, subscription ID, or public IP address.

| # | Screenshot | Azure Portal location | Evidence |
|---|---|---|---|
| 01 | Resource overview | Resource group → Overview | Primary/DR storage, VNet, VM, Private Endpoint, Private DNS, Log Analytics |
| 02 | Storage security | Primary storage → Configuration and Networking | HTTPS only, TLS 1.2, anonymous access disabled, firewall selected networks |
| 03 | Private access | Private Endpoint → Overview and Private DNS zone | Approved connection, private IP, Blob target, VNet link |
| 04 | Delegated access | Primary storage → Containers → contractor → Stored access policy | `contractor-read-policy` with read/list permissions |
| 05 | Encryption and protection | Primary storage → Encryption scopes and Data protection | `finance-scope`, versioning, change feed, soft delete, PITR |
| 06 | Cost optimization | Primary storage → Lifecycle management | `logs-cost-optimization` rule and `logs/` prefix |
| 07 | Disaster recovery | Primary storage → Object replication | Source/destination accounts, container pair, policy status |
| 08 | Operations | Blob service → Diagnostic settings, plus Azure Files snapshots | Log Analytics destination and operations share snapshot |

## Final evidence to copy from Cloud Shell

Run:

```bash
bash validate.sh | tee validation-output.txt
```

Save `validation-output.txt` for the GitHub evidence record. An anonymous request to the Blob service root may return `400` or `403`. Private DNS resolution to the Private Endpoint address is the primary network-path proof.
