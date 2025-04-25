# --- rockit-base-release.json
data "http" "base_release_json" {
   url = local.base_dx_url
   request_headers = {
      Accept = "application/json"
   }
}
locals {
   base_src_env     = jsondecode (data.http.base_release_json.response_body).env
   base_src_hash    = jsondecode (data.http.base_release_json.response_body).srcHash
   base_git_hash    = jsondecode (data.http.base_release_json.response_body).gitHash
   base_loader_url  = jsondecode (data.http.base_release_json.response_body).loader
   base_loader_hash = jsondecode (data.http.base_release_json.response_body).loaderHash
}

# --- generate custom VM image
resource "null_resource" "loader_img" {
   depends_on = [ null_resource.rockitplay_tag_namespace ]
   triggers = {
      # always     = timestamp ()
      src_updated = local.base_loader_hash
      # --- store destruction time data in triggers
      comp_id     = var.compartment_ocid
      workspace   = local.workspace
   }
   provisioner "local-exec" {
      interpreter = [ "/bin/bash", "-c" ]
      command = <<-EOT
         set -e
         requestId=$(oci compute image import from-object-uri --compartment-id ${var.compartment_ocid} --uri ${local.base_loader_url} --display-name "loader-img-${local.workspace}" --defined-tags '{"ROCKITPLAY-Tags": {"hash": "${local.base_git_hash}:${local.base_loader_hash}"}}' --launch-mode PARAVIRTUALIZED --operating-system "Ubuntu" --operating-system-version 24.04 | jq -r '.["opc-work-request-id"]')
         for (( ; ; )); do
            status=$(oci work-requests work-request get --work-request-id $requestId | jq -r '.data.status')
            if test x"$status" = x"SUCCEEDED"; then
               break
            fi
            sleep 15
         done
         # --- clean up older images
         imageOCIDs=$(oci compute image list --all --compartment-id=${var.compartment_ocid} --sort-by TIMECREATED --sort-order DESC | jq -r ".data | map(select (.[\"display-name\"]==\"loader-img-${local.workspace}\")) | .[1:] | .[][\"id\"]" | xargs)
         for imageOCID in $imageOCIDs; do
            oci compute image delete --force --image-id "$imageOCID"
         done
         imageId=$(oci compute image list --compartment-id ${var.compartment_ocid} --display-name loader-img-${local.workspace} | jq -r '.data[0].id')
         schemaId=$(oci compute image-capability-schema list --image-id $imageId | jq -r '.data[0].id')
         # --- Create schema setting to enable multipath support
         cat <<JSON_END > oci-mp.json
         {
            "Storage.Iscsi.MultipathDeviceSupported": {
               "default-value": true,
               "descriptor-type": "boolean",
               "source": "IMAGE"
            }
         }
         JSON_END
         if [ -z "$schemaId" ] || [ "$schemaId" == "null" ]; then
            # --- Create schema on image
            versionName=$(oci compute global-image-capability-schema list | jq -r '.data[0]."current-version-name"')
            oci compute image-capability-schema create --global-image-capability-schema-version-name $versionName --image-id $imageId --schema-data file://oci-mp.json --compartment-id ${var.compartment_ocid}
         else
            # --- Update existing schema on image
            oci compute image-capability-schema update --image-capability-schema-id $schemaId --schema-data file://oci-mp.json
         fi
         oci compute image-shape-compatibility-entry add --image-id $imageId --shape-name VM.DenseIO.E4.Flex
      EOT
   }
   # provisioner "local-exec" {
   #    when = destroy
   #    command = <<-EOT
   #       set -e
   #       imageOCIDs=$(oci compute image list --all --compartment-id=${self.triggers.comp_id} --sort-by TIMECREATED --sort-order DESC | jq -r ".data | map(select (.[\"display-name\"]==\"loader-img-${self.triggers.workspace}\")) | .[][\"id\"]" | xargs)
   #       for imageOCID in $imageOCIDs; do
   #          oci compute image delete --force --image-id "$imageOCID"
   #       done
   #    EOT
   # }
}

# --- Retrieve all remaining custom images at OCI AFTER cleanup
#     (should always by 1)
data "oci_core_images" "loader_images" {
   depends_on     = [ null_resource.loader_img ]
   compartment_id = var.compartment_ocid
   display_name   = "loader-img-${local.workspace}"
   sort_by        = "TIMECREATED"
   sort_order     = "ASC"
}