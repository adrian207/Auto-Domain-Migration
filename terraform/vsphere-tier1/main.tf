# vSphere Tier 1 (Demo) Implementation
# Author: Adrian Johnson <adrian207@gmail.com>
# Purpose: Deploy on-premises AD migration demo environment on vSphere

locals {
  vm_prefix = "${var.project_name}-${var.environment}"

  notes_tags = join("\n", [for k, v in var.tags : "${k}: ${v}"])
}

# Data sources for vSphere objects
data "vsphere_datacenter" "dc" {
  name = var.datacenter
}

data "vsphere_compute_cluster" "cluster" {
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "datastore" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = var.network_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

# VM Templates
data "vsphere_virtual_machine" "template_ubuntu" {
  name          = var.template_ubuntu_22
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template_windows_server" {
  name          = var.template_windows_server_2022
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template_windows_11" {
  name          = var.template_windows_11
  datacenter_id = data.vsphere_datacenter.dc.id
}

# Resource Pool (optional, can use cluster default)
resource "vsphere_resource_pool" "migration_pool" {
  name                    = "${local.vm_prefix}-pool"
  parent_resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
}

# VM Folder
resource "vsphere_folder" "vm_folder" {
  path          = "${var.project_name}/${var.environment}"
  type          = "vm"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# =============================================================================
# GUACAMOLE BASTION HOST
# =============================================================================

resource "vsphere_virtual_machine" "guacamole" {
  count            = var.enable_guacamole ? 1 : 0
  name             = "${local.vm_prefix}-guacamole"
  resource_pool_id = vsphere_resource_pool.migration_pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = vsphere_folder.vm_folder.path

  num_cpus = var.guacamole_vcpu
  memory   = var.guacamole_memory_mb
  guest_id = data.vsphere_virtual_machine.template_ubuntu.guest_id

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template_ubuntu.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = var.disk_size_gb
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template_ubuntu.id

    customize {
      linux_options {
        host_name = "${local.vm_prefix}-guacamole"
        domain    = var.domain
      }

      network_interface {
        ipv4_address = var.guacamole_ip
        ipv4_netmask = var.netmask
      }

      ipv4_gateway    = var.gateway
      dns_server_list = var.dns_servers
    }
  }

  extra_config = {
    "guestinfo.userdata" = base64encode(templatefile("${path.module}/cloud-init-guacamole.yaml", {
      postgres_host     = var.postgres_ip
      postgres_user     = var.admin_username
      postgres_password = var.postgres_password
      postgres_db       = "guacamole_db"
      admin_username    = var.admin_username
      admin_password    = var.admin_password
    }))
    "guestinfo.userdata.encoding" = "base64"
  }

  annotation = "${local.notes_tags}\nRole: Guacamole Bastion"
}

# =============================================================================
# ANSIBLE CONTROLLER
# =============================================================================

resource "vsphere_virtual_machine" "ansible" {
  name             = "${local.vm_prefix}-ansible"
  resource_pool_id = vsphere_resource_pool.migration_pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = vsphere_folder.vm_folder.path

  num_cpus = var.ansible_vcpu
  memory   = var.ansible_memory_mb
  guest_id = data.vsphere_virtual_machine.template_ubuntu.guest_id

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template_ubuntu.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = var.disk_size_gb
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template_ubuntu.id

    customize {
      linux_options {
        host_name = "${local.vm_prefix}-ansible"
        domain    = var.domain
      }

      network_interface {
        ipv4_address = var.ansible_controller_ip
        ipv4_netmask = var.netmask
      }

      ipv4_gateway    = var.gateway
      dns_server_list = var.dns_servers
    }
  }

  extra_config = {
    "guestinfo.userdata" = base64encode(templatefile("${path.module}/cloud-init-ansible.yaml", {
      postgres_host     = var.postgres_ip
      postgres_user     = var.admin_username
      postgres_password = var.postgres_password
    }))
    "guestinfo.userdata.encoding" = "base64"
  }

  annotation = "${local.notes_tags}\nRole: Ansible Controller"
}

# =============================================================================
# POSTGRESQL SERVER
# =============================================================================

resource "vsphere_virtual_machine" "postgres" {
  name             = "${local.vm_prefix}-postgres"
  resource_pool_id = vsphere_resource_pool.migration_pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = vsphere_folder.vm_folder.path

  num_cpus = var.postgres_vcpu
  memory   = var.postgres_memory_mb
  guest_id = data.vsphere_virtual_machine.template_ubuntu.guest_id

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template_ubuntu.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = var.disk_size_gb
    thin_provisioned = true
  }

  # Additional disk for PostgreSQL data
  disk {
    label            = "disk1"
    size             = 100
    thin_provisioned = true
    unit_number      = 1
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template_ubuntu.id

    customize {
      linux_options {
        host_name = "${local.vm_prefix}-postgres"
        domain    = var.domain
      }

      network_interface {
        ipv4_address = var.postgres_ip
        ipv4_netmask = var.netmask
      }

      ipv4_gateway    = var.gateway
      dns_server_list = var.dns_servers
    }
  }

  extra_config = {
    "guestinfo.userdata" = base64encode(templatefile("${path.module}/cloud-init-postgres.yaml", {
      postgres_password = var.postgres_password
      admin_username    = var.admin_username
    }))
    "guestinfo.userdata.encoding" = "base64"
  }

  annotation = "${local.notes_tags}\nRole: PostgreSQL Database"
}

# =============================================================================
# SOURCE DOMAIN CONTROLLER
# =============================================================================

resource "vsphere_virtual_machine" "source_dc" {
  name             = "${local.vm_prefix}-source-dc"
  resource_pool_id = vsphere_resource_pool.migration_pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = vsphere_folder.vm_folder.path

  num_cpus = var.dc_vcpu
  memory   = var.dc_memory_mb
  guest_id = data.vsphere_virtual_machine.template_windows_server.guest_id

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template_windows_server.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = max(var.disk_size_gb, data.vsphere_virtual_machine.template_windows_server.disks.0.size)
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template_windows_server.id

    customize {
      windows_options {
        computer_name    = "${local.vm_prefix}-src-dc"
        workgroup        = "WORKGROUP"
        admin_password   = var.admin_password
        auto_logon       = true
        auto_logon_count = 1
      }

      network_interface {
        ipv4_address = var.source_dc_ip
        ipv4_netmask = var.netmask
      }

      ipv4_gateway    = var.gateway
      dns_server_list = concat([var.source_dc_ip], var.dns_servers)
    }
  }

  annotation = "${local.notes_tags}\nRole: Source Domain Controller\nDomain: ${var.source_domain_fqdn}"
}

# =============================================================================
# TARGET DOMAIN CONTROLLER
# =============================================================================

resource "vsphere_virtual_machine" "target_dc" {
  name             = "${local.vm_prefix}-target-dc"
  resource_pool_id = vsphere_resource_pool.migration_pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = vsphere_folder.vm_folder.path

  num_cpus = var.dc_vcpu
  memory   = var.dc_memory_mb
  guest_id = data.vsphere_virtual_machine.template_windows_server.guest_id

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template_windows_server.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = max(var.disk_size_gb, data.vsphere_virtual_machine.template_windows_server.disks.0.size)
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template_windows_server.id

    customize {
      windows_options {
        computer_name    = "${local.vm_prefix}-tgt-dc"
        workgroup        = "WORKGROUP"
        admin_password   = var.admin_password
        auto_logon       = true
        auto_logon_count = 1
      }

      network_interface {
        ipv4_address = var.target_dc_ip
        ipv4_netmask = var.netmask
      }

      ipv4_gateway    = var.gateway
      dns_server_list = concat([var.target_dc_ip], var.dns_servers)
    }
  }

  annotation = "${local.notes_tags}\nRole: Target Domain Controller\nDomain: ${var.target_domain_fqdn}"
}

# =============================================================================
# TEST WORKSTATIONS
# =============================================================================

resource "vsphere_virtual_machine" "test_workstation" {
  count            = var.num_test_workstations
  name             = "${local.vm_prefix}-ws${format("%02d", count.index + 1)}"
  resource_pool_id = vsphere_resource_pool.migration_pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = vsphere_folder.vm_folder.path

  num_cpus = var.workstation_vcpu
  memory   = var.workstation_memory_mb
  guest_id = data.vsphere_virtual_machine.template_windows_11.guest_id

  network_interface {
    network_id   = data.vsphere_network.network.id
    adapter_type = data.vsphere_virtual_machine.template_windows_11.network_interface_types[0]
  }

  disk {
    label            = "disk0"
    size             = max(var.disk_size_gb, data.vsphere_virtual_machine.template_windows_11.disks.0.size)
    thin_provisioned = true
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template_windows_11.id

    customize {
      windows_options {
        computer_name  = "${local.vm_prefix}-ws${format("%02d", count.index + 1)}"
        workgroup      = "WORKGROUP"
        admin_password = var.admin_password
        auto_logon     = false
      }

      network_interface {
        ipv4_address = cidrhost(var.network_cidr, 100 + count.index)
        ipv4_netmask = var.netmask
      }

      ipv4_gateway    = var.gateway
      dns_server_list = concat([var.source_dc_ip], var.dns_servers)
    }
  }

  annotation = "${local.notes_tags}\nRole: Test Workstation\nWorkstation ID: ${count.index + 1}"
}

