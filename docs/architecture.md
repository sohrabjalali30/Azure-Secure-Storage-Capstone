# Architecture and Request Flow

## Logical architecture

```mermaid
flowchart TB
    CloudShell["Azure Cloud Shell"] --> Deploy["deploy.sh"]
    CloudShell --> Validate["validate.sh"]

    Deploy --> VNet["VNet: client + private endpoint subnets"]
    Deploy --> Primary["Primary StorageV2"]
    Deploy --> DR["DR StorageV2"]
    Deploy --> LAW["Log Analytics workspace"]

    VNet --> VM["Linux validation VM / no public IP"]
    VNet --> PE["Blob Private Endpoint"]
    PE --> Primary
    VM -->|"Private DNS resolution"| PE
    Primary -->|"Object Replication"| DR
    Primary -->|"Logs and metrics"| LAW
    Validate --> VM
```

## Private access flow

1. The VM requests the normal endpoint: `<storage>.blob.core.windows.net`.
2. Azure Private DNS returns the Private Endpoint address rather than the public Storage address.
3. Traffic remains on the VNet and reaches the Blob subresource through Private Link.
4. The Storage firewall remains at default action `Deny`.
5. Anonymous data access is still rejected even though network connectivity succeeds.

## Data-protection flow

```mermaid
flowchart LR
    Upload["Blob upload"] --> Versioning["Versioning"]
    Versioning --> SoftDelete["Soft delete"]
    SoftDelete --> PITR["Point-in-time restore"]
    Upload --> Scope["Encryption scope"]
    Upload --> Lifecycle["Lifecycle policy"]
    Upload --> Replication["Object replication"]
```

## Security boundaries

| Boundary | Control |
|---|---|
| Transport | HTTPS-only and TLS 1.2 minimum |
| Public data exposure | Anonymous Blob access disabled |
| Network | Firewall default `Deny`, selected subnet, Private Endpoint |
| Name resolution | Private DNS zone linked to the VNet |
| Identity | System-assigned Managed Identities |
| Delegation | Service SAS bound to a Stored Access Policy |
| Encryption | Platform encryption plus enforced finance encryption scope |
| Recovery | Versioning, soft delete, change feed, PITR, and replication |
| Monitoring | Storage diagnostics sent to Log Analytics |
