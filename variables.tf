# --- variables predefined by OCI Stacks
variable "tenancy_ocid" { }
variable "compartment_ocid" { }
variable "region" { }

# --- user-input by OCI
variable "dacslabs_link_b64"  { type = string }
variable "WORKSPACE"          { type = string }

variable "create_vault" {
  type = bool
}

variable "use_vault_ocid" {
  type    = string
  default = ""
}

variable "vault_comp_ocid" {
  type    = string
  default = ""
}

variable "WITH_CERT"       {
  type    = bool
  default = false
}
variable "CERT_OCID"       {
  type    = string
  default = "n/a"
}
variable "CERT_DOMAINNAME" {
  type    = string
  default = "n/a"
}

variable "MONGODBATLAS_ORGID" {
   type      = string
   sensitive = true
}
variable "MONGODBATLAS_ADMIN_PUBKEY"   { type = string }
variable "MONGODBATLAS_ADMIN_PRIVKEY"  {
   type      = string
   sensitive = true
}

variable "SLACK_TOKEN" {
  type      = string
  sensitive = true
}

locals {
  workspace     = lower (var.WORKSPACE)
  WORKSPACE     = upper (var.WORKSPACE)
  dacslabs_link = base64decode (split (".", var.dacslabs_link_b64)[1])
  base_dx_url   = split (",", local.dacslabs_link)[0]
  engine_dx_url = split (",", local.dacslabs_link)[1]
  edge_dx_url   = split (",", local.dacslabs_link)[2]
}
