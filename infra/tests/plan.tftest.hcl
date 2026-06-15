# Plan-only smoke test for the root module. Run with:
#   cd infra && terraform test
#
# Requires Azure auth (ARM_SUBSCRIPTION_ID + `az login` or service principal)
# because the azurerm provider validates the subscription on init -- no
# resources are created since command = plan.

run "plan_bastion_defaults" {
  command = plan

  variables {
    application_name = "tftest"
    access_mode      = "bastion"
  }
}

run "plan_public_ip" {
  command = plan

  variables {
    application_name     = "tftpip"
    access_mode          = "public_ip"
    allowed_ip_addresses = ["203.0.113.10/32"]
  }
}
