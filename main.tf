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

resource "oci_vault_secret" "rockitplay_dns_zone_ocid" {
   compartment_id = var.compartment_ocid
   vault_id       = local.vault_ocid
   key_id         = oci_kms_key.rockitplay_vault_key.id
   secret_name    = "ROCKITPLAY_DNS_ZONE_OCID.${random_password.baseenv_id.result}"
   description    = "OCID of DNS Zone to use of service records"
   secret_content {
      content_type = "BASE64"
      content      = base64encode(var.DNS_ZONE_OCID)
   }
}

resource "oci_vault_secret" "rockitplay_loader_image" {
   compartment_id = var.compartment_ocid
   vault_id       = local.vault_ocid
   key_id         = oci_kms_key.rockitplay_vault_key.id
   secret_name    = "ROCKITPLAY_LOADER_IMAGE_OCID.${random_password.baseenv_id.result}"
   description    = "OCID of the ROCKITPLAY task loader image"
   secret_content {
      content_type = "BASE64"
      content      = base64encode(data.oci_core_images.loader_images.images[0].id)
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

resource "oci_vault_secret" "rockitplay_ably_token" {
   count          = var.use_pubsub ? 1 : 0
   compartment_id = var.compartment_ocid
   vault_id       = local.vault_ocid
   key_id         = oci_kms_key.rockitplay_vault_key.id
   secret_name    = "ROCKITPLAY_ABLY_TOKEN.${random_password.baseenv_id.result}"
   description    = "Token to access Ably for Pub/Sub support"
   secret_content {
      content_type = "BASE64"
      content      = base64encode(var.ABLY_TOKEN)
   }
}

resource "null_resource" "baseenv_secrets_gc" {
   triggers   = { always = "${timestamp()}" }
   provisioner "local-exec" {
      interpreter = [ "/bin/bash", "-c" ]
      command = <<-EOT
         secrets=$(oci vault secret list --compartment-id ${var.compartment_ocid} --all | jq -e -r '.data[] | select(."lifecycle-state" | contains("ACTIVE")) | "\(."secret-name")=\(.id)"')

         for secret in $secrets; do
            name=$(echo $secret | cut -d= -f 1)
            ocid=$(echo $secret | cut -d= -f 2)

            deletable_versions=$(oci secrets secret-bundle-version list-versions --secret-id $ocid --all | jq -r '.data[] | select(.stages[] | contains("DEPRECATED") or contains("RETIRED")) | ."version-number"' )

            for version in $deletable_versions; do
               delete_at="$(date -d "+2 days" +%Y-%m-%dT%H:%M:%SZ)"
               echo "scheduling deletion for secret=$name content_version=$version"
               oci vault secret-version schedule-deletion --secret-id $ocid --secret-version-number $version --time-of-deletion "$delete_at"
            done
         done
      EOT
   }
}

# --- ROCKITPLAY Tags
resource "null_resource" "rockitplay_tag_namespace" {
   triggers = {
     always = timestamp ()
   }
   provisioner "local-exec" {
      interpreter = [ "/bin/bash", "-c" ]
      command = <<EOT

      # Variables
      COMPARTMENT_ID="${var.tenancy_ocid}"
      NAMESPACE_NAME="ROCKITPLAY-Tags"
      NAMESPACE_DESCRIPTION="Tag namespace for all ROCKITPLAY instances"

      oci iam tag-namespace create \
      --compartment-id "$COMPARTMENT_ID" \
      --name "$NAMESPACE_NAME" \
      --description "$NAMESPACE_DESCRIPTION" \
      2>/dev/null \
      || echo "Namespace $NAMESPACE_NAME already exists, ignoring."

      NAMESPACE_ID=$(oci iam tag-namespace list --compartment-id "$COMPARTMENT_ID" --all | jq -r --arg NAMESPACE_NAME "$NAMESPACE_NAME" '.data[] | select(.name == $NAMESPACE_NAME) | .id')

      oci iam tag create --name "orgName"  --is-cost-tracking true --description "ROCKIT organization identifier" --tag-namespace-id $NAMESPACE_ID 2>/dev/null || echo "Tag already exists, ignoring."
      oci iam tag create --name "appName"  --is-cost-tracking true --description "ROCKIT app identifier"          --tag-namespace-id $NAMESPACE_ID 2>/dev/null || echo "Tag already exists, ignoring."
      oci iam tag create --name "taskType" --is-cost-tracking true --description "ROCKIT task identifier"         --tag-namespace-id $NAMESPACE_ID 2>/dev/null || echo "Tag already exists, ignoring."
      oci iam tag create --name "appPath"  --is-cost-tracking true --description "ROCKIT unique app identifier"   --tag-namespace-id $NAMESPACE_ID 2>/dev/null || echo "Tag already exists, ignoring."

      oci iam tag create --name "instanceName" --is-cost-tracking false --description "ROCKIT instance name"      --tag-namespace-id $NAMESPACE_ID 2>/dev/null || echo "Tag already exists, ignoring."
      oci iam tag create --name "taskLoader"   --is-cost-tracking false --description "ROCKIT Task Loader"        --tag-namespace-id $NAMESPACE_ID 2>/dev/null || echo "Tag already exists, ignoring."
      oci iam tag create --name "hash"         --is-cost-tracking false --description "Git commit or source hash" --tag-namespace-id $NAMESPACE_ID 2>/dev/null || echo "Tag already exists, ignoring."

      EOT
   }
}

# resource "oci_identity_tag_namespace" "rockitplay_tag_namespace" {
#    count          = local.tag_namespace_exists == false ? 1 : 0
#    compartment_id = var.tenancy_ocid
#    description    = "ROCKITPLAY Tags"
#    name           = "ROCKITPLAY-Tags"
#    lifecycle { prevent_destroy = true }
# }
# resource "oci_identity_tag" "appName" {
#    count            = local.tag_namespace_exists == false ? 1 : 0
#    tag_namespace_id = oci_identity_tag_namespace.rockitplay_tag_namespace[0].id
#    description      = "ROCKIT App Name"
#    name             = "appName"
#    is_cost_tracking = true
#    lifecycle { prevent_destroy = true }
# }
# resource "oci_identity_tag" "instanceName" {
#    count            = local.tag_namespace_exists == false ? 1 : 0
#    tag_namespace_id = oci_identity_tag_namespace.rockitplay_tag_namespace[0].id
#    description      = "ROCKIT Instance Name"
#    name             = "instanceName"
#    is_cost_tracking = true
#    lifecycle { prevent_destroy = true }
# }
# resource "oci_identity_tag" "orgName" {
#    count            = local.tag_namespace_exists == false ? 1 : 0
#    tag_namespace_id = oci_identity_tag_namespace.rockitplay_tag_namespace[0].id
#    description      = "ROCKIT Organization Name"
#    name             = "orgName"
#    is_cost_tracking = true
#    lifecycle { prevent_destroy = true }
# }
# resource "oci_identity_tag" "taskType" {
#    count            = local.tag_namespace_exists == false ? 1 : 0
#    tag_namespace_id = oci_identity_tag_namespace.rockitplay_tag_namespace[0].id
#    description      = "ROCKIT Task Type"
#    name             = "taskType"
#    is_cost_tracking = true
#    lifecycle { prevent_destroy = true }
# }
# resource "oci_identity_tag" "taskLoader" {
#    count            = local.tag_namespace_exists == false ? 1 : 0
#    tag_namespace_id = oci_identity_tag_namespace.rockitplay_tag_namespace[0].id
#    description      = "ROCKIT Task Loader"
#    name             = "taskLoader"
#    is_cost_tracking = false
#    lifecycle { prevent_destroy = true }
# }
# resource "oci_identity_tag" "hash" {
#    count            = local.tag_namespace_exists == false ? 1 : 0
#    tag_namespace_id = oci_identity_tag_namespace.rockitplay_tag_namespace[0].id
#    description      = "Git commit or source hash"
#    name             = "hash"
#    is_cost_tracking = false
#    lifecycle { prevent_destroy = true }
# }

resource "oci_identity_dynamic_group" "rockit_loader_dyngrp" {
    compartment_id = var.tenancy_ocid
    description    = "ROCKIT Task Loader [${random_password.baseenv_id.result}]"
    matching_rule  = "tag.ROCKITPLAY-Tags.taskLoader.value = 'rockit-loader-${random_password.baseenv_id.result}'"
    name           = "rockit-loader-dyngrp-${random_password.baseenv_id.result}"
}


resource "oci_identity_policy" "rockit_loader_tenancy_rt_pol" {
   compartment_id = var.tenancy_ocid
   description    = "ROCKIT Loader [${random_password.baseenv_id.result}] Runtime Tenancy Policy"
   name           = "rockit-loader-tenancy-rt-pol-${random_password.baseenv_id.result}"
   depends_on     = [ oci_identity_dynamic_group.rockit_loader_dyngrp ]
   statements     = [
      "Allow dynamic-group rockit-loader-dyngrp-${random_password.baseenv_id.result} to use instance-family in compartment id ${var.compartment_ocid}",
   ]
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

output "rockit_base_link"  { value = "dxbaselnk1.${local.rockit_base_link_data}" }
output "version"           { value = var.VERSION }
