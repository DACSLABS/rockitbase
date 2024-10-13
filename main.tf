# File Structure:
# - schema.yaml  (OCI Stack User Input)
# - variables.tf (environment variables)
# - providers.tf (Terraform providers)

# --- define unique identifier for this environment
resource "random_password" "baseenv_id" {
   length           = 10
   special          = false
   upper            = true
   lower            = true
   numeric          = true
   min_upper        = 1
   min_lower        = 1
   min_numeric      = 1
}

resource "oci_kms_vault" "rockitplay_vault" {
   count          = var.create_vault ? 1 : 0
   compartment_id = var.compartment_ocid
   display_name   = "rockitplay-vault"
   vault_type     = "DEFAULT"
}
data "oci_kms_vault" "rockitplay_vault" {
   count    = var.create_vault ? 0 : 1
   vault_id = var.use_vault_ocid
}

resource "oci_kms_key" "rockitplay_vault_key" {
   compartment_id = var.compartment_ocid
    display_name  = "rockitplay-master-key"
    protection_mode = "SOFTWARE"
    key_shape {
        algorithm = "AES"
        length    = 32
    }
    management_endpoint = var.create_vault ? oci_kms_vault.rockitplay_vault[0].management_endpoint : data.oci_kms_vault.rockitplay_vault[0].management_endpoint
}

locals {
   vault_ocid = var.create_vault ? oci_kms_vault.rockitplay_vault[0].id : var.use_vault_ocid
}

resource "oci_vault_secret" "rockitplay_cert_ocid" {
   compartment_id = var.compartment_ocid
   vault_id       = local.vault_ocid
   key_id         = oci_kms_key.rockitplay_vault_key.id
   secret_name    = "ROCKITPLAY_CERT_OCID.${random_password.baseenv_id.result}"
   description    = "OCID of SSL wildcard certificate"
   secret_content {
      content_type = "BASE64"
      content      = base64encode(var.CERT_OCID)
   }
}

resource "oci_vault_secret" "rockitplay_cert_domainname" {
   compartment_id = var.compartment_ocid
   vault_id       = local.vault_ocid
   key_id         = oci_kms_key.rockitplay_vault_key.id
   secret_name    = "ROCKITPLAY_CERT_DOMAINNAME.${random_password.baseenv_id.result}"
   description    = "Domain name of SSL wildcard certificate"
   secret_content {
      content_type = "BASE64"
      content      = base64encode(var.CERT_DOMAINNAME)
   }
}

resource "oci_vault_secret" "rockitplay_mongodbatlas_orgid" {
   compartment_id = var.compartment_ocid
   vault_id       = local.vault_ocid
   key_id         = oci_kms_key.rockitplay_vault_key.id
   secret_name    = "ROCKITPLAY_MONGODBATLAS_ORGID.${random_password.baseenv_id.result}"
   description    = "MongoDB Atlas Organization ID"
   secret_content {
      content_type = "BASE64"
      content      = base64encode(var.MONGODBATLAS_ORGID)
   }
}

resource "oci_vault_secret" "rockitplay_mongodbatlas_admin_pubkey" {
   compartment_id = var.compartment_ocid
   vault_id       = local.vault_ocid
   key_id         = oci_kms_key.rockitplay_vault_key.id
   secret_name    = "ROCKITPLAY_MONGODBATLAS_ADMIN_PUBKEY.${random_password.baseenv_id.result}"
   description    = "Public key to manage MongoDB Atlas"
   secret_content {
      content_type = "BASE64"
      content      = base64encode(var.MONGODBATLAS_ADMIN_PUBKEY)
   }
}

resource "oci_vault_secret" "rockitplay_mongodbatlas_admin_privkey" {
   compartment_id = var.compartment_ocid
   vault_id       = local.vault_ocid
   key_id         = oci_kms_key.rockitplay_vault_key.id
   secret_name    = "ROCKITPLAY_MONGODBATLAS_ADMIN_PRIVKEY.${random_password.baseenv_id.result}"
   description    = "Private key to manage MongoDB Atlas"
   secret_content {
      content_type = "BASE64"
      content      = base64encode(var.MONGODBATLAS_ADMIN_PRIVKEY)
   }
}

resource "oci_vault_secret" "rockitplay_slack_token" {
   compartment_id = var.compartment_ocid
   vault_id       = local.vault_ocid
   key_id         = oci_kms_key.rockitplay_vault_key.id
   secret_name    = "ROCKITPLAY_SLACK_TOKEN.${random_password.baseenv_id.result}"
   description    = "Token to access Slack to send notifications"
   secret_content {
      content_type = "BASE64"
      content      = base64encode(var.SLACK_TOKEN)
   }
}

# --- ROCKITPLAY Tags
resource "oci_identity_tag_namespace" "rockitplay_tag_namespace" {
    compartment_id = var.tenancy_ocid
    description    = "ROCKITPLAY Tags"
    name           = "ROCKITPLAY-Tags"
}
resource "oci_identity_tag" "appName" {
    tag_namespace_id = oci_identity_tag_namespace.rockitplay_tag_namespace.id
    description      = "ROCKIT App Name"
    name             = "appName"
    is_cost_tracking = true
}
resource "oci_identity_tag" "instanceName" {
    tag_namespace_id = oci_identity_tag_namespace.rockitplay_tag_namespace.id
    description      = "ROCKIT Instance Name"
    name             = "instanceName"
    is_cost_tracking = true
}
resource "oci_identity_tag" "orgName" {
    tag_namespace_id = oci_identity_tag_namespace.rockitplay_tag_namespace.id
    description      = "ROCKIT Organization Name"
    name             = "orgName"
    is_cost_tracking = true
}
resource "oci_identity_tag" "taskType" {
    tag_namespace_id = oci_identity_tag_namespace.rockitplay_tag_namespace.id
    description      = "ROCKIT Task Type"
    name             = "taskType"
    is_cost_tracking = true
}

locals {
   rockit_base_link_args = [
      var.compartment_ocid,
      local.vault_ocid,
      oci_kms_key.rockitplay_vault_key.id,
      random_password.baseenv_id.result
   ]
   rockit_base_link_data = nonsensitive(base64encode (join (",", local.rockit_base_link_args)))
}

output "rockit_base_link"  {
  value = "dxbaselnk1.${local.rockit_base_link_data}"
}