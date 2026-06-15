locals {
  naming_token         = var.application_name != "" ? var.application_name : random_pet.naming.id
  naming_token_compact = substr(lower(replace(local.naming_token, "-", "")), 0, 14)

  default_tags = {
    workload    = "cyclecloud"
    deployed_by = "terraform"
    environment = local.naming_token
  }

  tags = merge(local.default_tags, var.tags)

  # Operator IP auto-detected at plan time so the caller machine always lands on KV/NSG allow-lists.
  caller_ip          = chomp(data.http.caller_ip.response_body)
  allowed_source_ips = distinct(concat(var.allowed_ip_addresses, ["${local.caller_ip}/32"]))
}
