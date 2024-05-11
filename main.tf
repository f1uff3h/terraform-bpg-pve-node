terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">=0.55"
    }
  }
}

locals {
  default_fsgs = {
    webserver = {
      rules = [
        {
          direction = "in"
          action    = "ACCEPT"
          comment   = "Allow HTTP"
          dport     = "80"
          proto     = "tcp"
          log       = "info"
        },
        {
          direction = "in"
          action    = "ACCEPT"
          comment   = "Allow HTTPS"
          dport     = "443"
          proto     = "tcp"
          log       = "info"
        }
      ]
    }
    mailserver = {
      rules = [
        {
          direction = "in"
          action    = "ACCEPT"
          comment   = "Allow SMTP"
          dport     = "25"
          proto     = "tcp"
          log       = "info"
        },
        {
          direction = "in"
          action    = "ACCEPT"
          comment   = "Allow SMTPS"
          dport     = "465"
          proto     = "tcp"
          log       = "info"
        },
        {
          direction = "in"
          action    = "ACCEPT"
          comment   = "Allow IMAP"
          dport     = "143"
          proto     = "tcp"
          log       = "info"
        },
        {
          direction = "in"
          action    = "ACCEPT"
          comment   = "Allow IMAPS"
          dport     = "993"
          proto     = "tcp"
          log       = "info"
        },
        {
          direction = "in"
          action    = "ACCEPT"
          comment   = "Allow POP3"
          dport     = "110"
          proto     = "tcp"
          log       = "info"
        },
        {
          direction = "in"
          action    = "ACCEPT"
          comment   = "Allow POP3S"
          dport     = "995"
          proto     = "tcp"
          log       = "info"
        }
      ]
    }
    ldapserver = {
      rules = [
        {
          direction = "in"
          action    = "ACCEPT"
          comment   = "Allow LDAP"
          dport     = "389"
          proto     = "tcp"
          log       = "info"
        },
        {
          direction = "in"
          action    = "ACCEPT"
          comment   = "Allow LDAPS"
          dport     = "636"
          proto     = "tcp"
          log       = "info"
        }
      ]
    }
  }
}

resource "proxmox_virtual_environment_cluster_options" "dtc_opts" {
  description = <<-EOT
	${var.dtc-description}
	
	Managed by Terraform
  EOT

  language   = var.ui-language
  keyboard   = var.vnc-kb-layout
  http_proxy = var.http-proxy
  console    = var.dtc-console-viewer
  email_from = var.dtc-email
  mac_prefix = var.dtc-mac-prefix

  migration_type = var.dtc-migration-type
  migration_cidr = var.dtc-migration-cidr

  ha_shutdown_policy        = var.dtc-ha-policy
  crs_ha                    = var.dtc-crs.ha
  crs_ha_rebalance_on_start = var.dtc-crs.ha-rebalance

  bandwidth_limit_default   = var.dtc-bw-limits.default
  bandwidth_limit_restore   = var.dtc-bw-limits.restore
  bandwidth_limit_migration = var.dtc-bw-limits.migration
  bandwidth_limit_clone     = var.dtc-bw-limits.clone
  bandwidth_limit_move      = var.dtc-bw-limits.move

  max_workers = var.dtc-max-workers
  next_id = {
    lower = var.dtc-vmid-range.lower
    upper = var.dtc-vmid-range.upper
  }
}

resource "proxmox_virtual_environment_cluster_firewall" "dtc_fw" {
  enabled = var.dtc-fw-enabled

  ebtables      = var.dtc-fw-ebtables
  input_policy  = var.dtc-fw-inpol
  output_policy = var.dtc-fw-outpol
  log_ratelimit {
    enabled = var.dtc-fw-lrl.enabled
    burst   = var.dtc-fw-lrl.burst
    rate    = var.dtc-fw-lrl.rate
  }
}

resource "proxmox_virtual_environment_cluster_firewall_security_group" "default_fsgs" {
  for_each = local.default_fsgs

  name    = each.key
  comment = "Managed by Terraform"

  dynamic "rule" {
    for_each = each.value.rules
    content {
      enabled = true
      action  = rule.value.action
      type    = rule.value.direction
      dport   = rule.value.dport
      proto   = rule.value.proto
      log     = rule.value.log
      comment = "${rule.value.comment == null ? "" : rule.value.comment}; Managed by Terraform"
    }
  }
}

resource "proxmox_virtual_environment_cluster_firewall_security_group" "fsg" {
  for_each = var.dtc-fsg

  name    = each.key
  comment = <<-EOT
  
	${each.value.comment}

	Managed by Terraform
  EOT

  dynamic "rule" {
    for_each = each.value.rules
    content {
      enabled = rule.value.enabled
      iface   = rule.value.iface
      action  = rule.value.action
      type    = rule.value.direction
      source  = rule.value.sourceip
      dest    = rule.value.destip
      sport   = rule.value.sport
      dport   = rule.value.dport
      proto   = rule.value.proto
      log     = rule.value.log
      comment = "${rule.value.comment == null ? "" : rule.value.comment}; Managed by Terraform"
    }
  }
}

resource "proxmox_virtual_environment_firewall_rules" "dtc_rules" {
  count     = length(var.dtc-fw-rules) == 0 || length(var.dtc-fw-fsg) == 0 ? 0 : 1
  node_name = var.node-name

  dynamic "rule" {
    for_each = var.dtc-fw-rules

    content {
      enabled = rule.value.enabled
      iface   = rule.value.iface
      action  = rule.value.action
      type    = rule.value.direction
      source  = rule.value.sourceip
      dest    = rule.value.destip
      sport   = rule.value.sport
      dport   = rule.value.dport
      proto   = rule.value.proto
      log     = rule.value.log
      comment = "${rule.value.comment == null ? "" : rule.value.comment}; Managed by Terraform"
    }
  }

  dynamic "rule" {
    for_each = var.dtc-fw-fsg

    content {
      enabled        = rule.value.enabled
      security_group = rule.value.fsg
      iface          = rule.value.iface
      comment        = "${rule.value.comment == null ? "" : rule.value.comment}; Managed by Terraform"
    }
  }

}

resource "proxmox_virtual_environment_pool" "dtc_pools" {
  for_each = var.dtc-pools

  pool_id = each.key
  comment = "Managed by Terraform"
}

resource "proxmox_virtual_environment_time" "node_timezone" {
  node_name = var.node-name
  time_zone = var.node-timezone
}

resource "proxmox_virtual_environment_dns" "node_dns" {
  count = var.node-dns != null ? 1 : 0

  node_name = var.node-name
  domain    = var.node-dns.search-domain

  servers = var.node-dns.servers != null ? var.node-dns.servers : []
}

resource "proxmox_virtual_environment_hosts" "node_hosts_file" {
  node_name = var.node-name

  entry {
    address = "127.0.0.1"

    hostnames = [
      "localhost.localdomain",
      "localhost"
    ]
  }
  dynamic "entry" {
    for_each = var.node-hosts-entries

    content {
      address   = entry.value.address
      hostnames = entry.value.hostnames
    }
  }
}

resource "proxmox_virtual_environment_network_linux_bridge" "vmbr" {
  for_each = var.node-bridges

  node_name = var.node-name
  name      = each.key
  autostart = each.value.autostart
  comment   = "${each.value.comment}; Managed by Terraform"

  address = each.value.ipv4-cidr
  gateway = each.value.ipv4-gw

  address6 = each.value.ipv6-cidr
  gateway6 = each.value.ipv6-gw

  mtu        = each.value.mtu
  ports      = each.value.bridged-ports
  vlan_aware = each.value.vlan_aware
}

resource "null_resource" "bootstrap_missing_provider_settings" {
  count = var.run-bootstrap ? 1 : 0

  triggers = {
    case  = try(var.dtc-tag.case, "0")
    orer  = try(var.dtc-tag.order, "0")
    shape = try(var.dtc-tag.shape, "0")
  }

  connection {
    type        = "ssh"
    host        = var.node-ip
    user        = var.node-ssh-user
    password    = var.node-ssh-pw
    private_key = var.node-ssh-privkey
  }

  provisioner "remote-exec" {
    inline = [
      # if there is a better option I'm all ears
      "pvesh set cluster/options -tag-style ${var.dtc-tag.case != null ? "case-sensitive=${var.dtc-tag.case}" : ""},${var.dtc-tag.order != null ? "ordering=${var.dtc-tag.order}" : ""},${var.dtc-tag.shape != null ? "shape=${var.dtc-tag.shape}" : ""}",
      "pvesh set nodes/${var.node-name}/firewall/options -enable ${var.node-fw-enabled}",
      "pvesh set nodes/${var.node-name}/firewall/options -log_level_in ${var.node-fw-log-in}",
      "pvesh set nodes/${var.node-name}/firewall/options -log_level_out ${var.node-fw-log-out}",
      "pvesh set nodes/${var.node-name}/firewall/options -nosmurfs ${var.node-fw-smurfs}",
      "pvesh set nodes/${var.node-name}/firewall/options -smurf_log_level ${var.node-fw-smurfs-log}",
      "pvesh set nodes/${var.node-name}/firewall/options -tcpflags ${var.node-fw-tcpflags}",
      "pvesh set nodes/${var.node-name}/firewall/options -tcp_flags_log_level ${var.node-fw-tcpflags-log}",
      "pvesh set nodes/${var.node-name}/firewall/options -ndp ${var.node-fw-ndp}",
    ]
  }

  lifecycle {
    precondition {
      condition     = (var.node-ssh-pw == null && var.node-ssh-privkey != null) || (var.node-ssh-pw != null && var.node-ssh-privkey == null)
      error_message = "Password or private key (not both) must be provided for the ssh connection!"
    }
  }
}
