## :cloud: WCD Phase-2 Data Engineering Project
#### Azure Big Data using yelp reviews

### Requirements

- Terraform installed
- Azure Account
- Azure CLI installed

----

#### Azure Key Vault 
----
An Azure Key Vault is needed external to the project to hold some of the config variables:
| Secret Name | Description |
--------------|--------------
| PgUsername | Username to access WCD External RDS Postgres Database |
| PgPassword | Password to access WCD External RDS Postgres Database |
| WcdBlobStorageAccount | Name of the WCD Azure Storage Blob |
| WcdBlobStorageKey | Key to access WCD Azure Storage Blob |
| SynapseSqlUser | A username for your Synapse SQL database |
| SynapseSqlPassword | A password for your Synapse SQL database |

The WCD External RDS Postgres database has the following tables with yelp information: businesses, checkin, tip, and users.

The WCD Azure Storage Blob contains parquet files with yelp reviews partitioned by date.

----

#### terraform.tfvars file
----
A `.tfvars` file is needed for other config variables

| Variable Name | Description |
----------------|--------------
| pg_host_name | Host name for WCD RDS Postgres Database |
| pg_database_name | Database name for WCD RDS Postgres Database |
| wcd_blob_container | Name of the WCD Azure Storage Blob Container |
| wcd_blob_folder | Name of the WCD Azure Storage Blob Folder |
| external_key_vault_resource_group | Azure Resource Group Name for config Key Vault |
| external_key_vault_name | Name of the config Key Vault |
| my_azure_login_name | Your Azure login name |
| databricks_account_id | Databricks ID from new workspace |
| my_ip | Your IP address to connect to Synapse resources |

If the `databricks_account_id` is not known, it will be generated once the workspace is created. In that case, `terraform apply` will error before building databricks resources. The account id can be found through the *databricks account console* by clicking the down arrow next to your username in the upper-right corner. Once it is added to the `.tfvars` file then run `terraform apply` again to finish building the remaining resources.

