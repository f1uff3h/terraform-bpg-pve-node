terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
    }
  }
}

provider "proxmox" {
  insecure = true
}

module "basic_node" {
  source = "../../"

  node-name = "my-basic-pve-node"
}
