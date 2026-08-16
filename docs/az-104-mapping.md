# AZ-104 Objective Mapping

This project was built specifically as practical preparation for the Microsoft AZ-104 exam.

| AZ-104 skill area | Project implementation | Evidence |
|---|---|---|
| Configure Storage accounts | Two general-purpose v2 accounts with secure defaults | `deploy.sh`, Storage security validation |
| Configure redundancy and replication | Source/destination Object Replication policies | Policy count `1/1` |
| Secure Storage endpoints | Firewall default `Deny`, Service Endpoint, Private Endpoint | Network and Private Endpoint validation |
| Configure private access | Blob Private Endpoint and Private DNS | Resolution to `10.40.2.4` from the VM |
| Configure Blob protection | Versioning, Change Feed, soft delete, container soft delete, PITR | `validate.sh` output |
| Configure lifecycle management | Cost-optimization rule for the `logs/` prefix | Lifecycle validation |
| Configure encryption | Microsoft-managed keys and enforced finance encryption scope | Encryption-scope validation |
| Configure delegated access | Service SAS linked to a Stored Access Policy | Required deployment step |
| Configure Azure Files | Operations share, file upload, and snapshot workflow | Deployment script |
| Configure monitoring | Storage read/write/delete logs and transaction metrics | Diagnostic setting linked to Log Analytics |
| Configure Managed Identity | System-assigned identities on Storage and VM | Storage security and resource configuration |
| Administer with Azure CLI | Automated deployment and read-only validation | `deploy.sh`, `validate.sh` |

## Exam concepts reinforced

- A Private Endpoint is created per Storage subresource; this project creates one for Blob.
- A Storage firewall rule and a Private Endpoint solve related but different network-access requirements.
- A Stored Access Policy provides central control over compatible Service SAS tokens.
- User Delegation SAS is preferred when Microsoft Entra-based delegation is available; Account SAS has a broader potential scope.
- Versioning, soft delete, PITR, lifecycle management, and replication solve different recovery and governance requirements.
- Customer-Managed Keys require both a supported Key Vault configuration and correct identity/RBAC permissions.
- Diagnostic Settings route platform logs and metrics; they do not replace Storage data-protection features.
