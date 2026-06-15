# Example dev environment overrides. Copy to dev.tfvars (gitignored) and edit.
#   cp dev.example.tfvars dev.tfvars

application_name     = "dev"
location             = "eastus2"
access_mode          = "bastion"
allowed_ip_addresses = []
vnet_address_space   = ["10.150.0.0/16"]
log_retention_days   = 30
server_vm_size       = "Standard_D4s_v5"

server_image = {
  source = "marketplace"
  marketplace = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

tags = {
  environment = "dev"
  owner       = "hpc-team"
}
