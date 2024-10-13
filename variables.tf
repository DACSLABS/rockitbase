# --- variables predefined by OCI Stacks
variable "tenancy_ocid" { }
variable "compartment_ocid" { }
variable "region" { }

# --- user-input by OCI
variable "create_vault" {
  type = bool
}

variable "use_vault_ocid" {
  type = string
}

variable "vault_comp_ocid" { type = string }

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