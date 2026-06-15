# Example production environment overrides. Copy to prod.tfvars (gitignored) and edit.
#   cp prod.example.tfvars prod.tfvars

application_name     = "prod"
location             = "eastus2"
access_mode          = "bastion"
allowed_ip_addresses = []
vnet_address_space   = ["10.150.0.0/16"]
log_retention_days   = 90
server_vm_size       = "Standard_D8s_v5"

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
  environment = "prod"
  owner       = "hpc-team"
  costcenter  = "research"
}
