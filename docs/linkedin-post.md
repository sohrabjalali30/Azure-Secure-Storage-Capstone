# LinkedIn Post Draft

I recently completed an **Azure Secure Storage Capstone** as part of my hands-on preparation for the **Microsoft AZ-104: Azure Administrator** exam.

The goal was to move beyond isolated Portal exercises and build a repeatable Storage platform using **Bash and Azure CLI**.

The project automated and validated:

- Secure transfer, TLS 1.2, and disabled anonymous Blob access
- Storage firewall rules, a Blob Private Endpoint, and Private DNS
- Managed Identities and an enforced encryption scope
- Versioning, Change Feed, soft delete, and point-in-time restore
- Lifecycle cost optimization
- Service SAS controlled by a Stored Access Policy
- Azure Files and snapshot workflow
- Object Replication between two Storage accounts
- Diagnostic logs and metrics sent to Log Analytics

One of my biggest lessons was seeing how powerful scripting becomes in cloud administration. The complete environment was deployed in about six and a half minutes, with automated validation and fallback handling for sandbox restrictions.

The training sandbox did not allow full Key Vault RBAC configuration or a second Azure region, so I documented these limitations and included Customer-Managed Keys and geographic DR in the production roadmap.

This project strengthened both my AZ-104 knowledge and my interest in developing deeper skills in Bash, Azure CLI, Infrastructure as Code, and cloud automation.

GitHub: [add repository URL]

#Azure #AZ104 #AzureStorage #Bash #CloudEngineering
