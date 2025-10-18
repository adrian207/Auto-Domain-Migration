# vSphere Tier 2 (Production) Implementation
# Author: Adrian Johnson <adrian207@gmail.com>
# Purpose: Deploy production-scale AD migration environment on vSphere with HA

locals {
  vm_prefix = "${var.project_name}-${var.environment}"

  notes_tags = join("\n", [for k, v in var.tags : "${k}: ${v}"])
}

# =============================================================================
# DATA SOURCES
# =============================================================================

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

data "vsphere_datastore" "backup" {
  count         = var.datastore_backup != "" ? 1 : 0
  name          = var.datastore_backup
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "network" {
  name          = var.network_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template_ubuntu" {
  name          = var.template_ubuntu_22
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_virtual_machine" "template_windows_server" {
  name          = var.template_windows_server_2022
  datacenter_id = data.vsphere_datacenter.dc.id
}

# =============================================================================
# RESOURCE POOL
# =============================================================================

resource "vsphere_resource_pool" "migration_pool" {
  name                    = "${local.vm_prefix}-pool"
  parent_resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id

  cpu_share_level = "normal"
  cpu_reservation = 10000 # 10 GHz reserved
  cpu_expandable  = true

  memory_share_level = "normal"
  memory_reservation = 65536 # 64 GB reserved
  memory_expandable  = true
}

# VM Folder
resource "vsphere_folder" "vm_folder" {
  path          = "${var.project_name}/${var.environment}"
  type          = "vm"
  datacenter_id = data.vsphere_datacenter.dc.id
}

# =============================================================================
# DRS ANTI-AFFINITY RULES (Keep HA VMs on different hosts)
# =============================================================================

# Anti-affinity for Ansible controllers
resource "vsphere_compute_cluster_vm_anti_affinity_rule" "ansible_anti_affinity" {
  count               = var.enable_drs_anti_affinity && var.num_ansible_controllers > 1 ? 1 : 0
  name                = "${local.vm_prefix}-ansible-anti-affinity"
  compute_cluster_id  = data.vsphere_compute_cluster.cluster.id
  virtual_machine_ids = vsphere_virtual_machine.ansible[*].id
  enabled             = true
  mandatory           = false
}

# Anti-affinity for PostgreSQL cluster
resource "vsphere_compute_cluster_vm_anti_affinity_rule" "postgres_anti_affinity" {
  count               = var.enable_drs_anti_affinity && var.num_postgres_nodes > 1 ? 1 : 0
  name                = "${local.vm_prefix}-postgres-anti-affinity"
  compute_cluster_id  = data.vsphere_compute_cluster.cluster.id
  virtual_machine_ids = vsphere_virtual_machine.postgres[*].id
  enabled             = true
  mandatory           = false
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
        ipv4_address = cidrhost(var.network_cidr, 10)
        ipv4_netmask = var.netmask
      }

      ipv4_gateway    = var.gateway
      dns_server_list = var.dns_servers
    }
  }

  annotation = "${local.notes_tags}\nRole: Guacamole Bastion"
}

# =============================================================================
# ANSIBLE/AWX CONTROLLERS (Multiple for HA)
# =============================================================================

resource "vsphere_virtual_machine" "ansible" {
  count            = var.num_ansible_controllers
  name             = "${local.vm_prefix}-ansible-${count.index + 1}"
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
        host_name = "${local.vm_prefix}-ansible-${count.index + 1}"
        domain    = var.domain
      }

      network_interface {
        ipv4_address = cidrhost(var.network_cidr, 20 + count.index)
        ipv4_netmask = var.netmask
      }

      ipv4_gateway    = var.gateway
      dns_server_list = var.dns_servers
    }
  }

  annotation = "${local.notes_tags}\nRole: Ansible/AWX Controller\nInstance: ${count.index + 1}"
}

# =============================================================================
# POSTGRESQL CLUSTER (Patroni + etcd for HA)
# =============================================================================

resource "vsphere_virtual_machine" "postgres" {
  count            = var.num_postgres_nodes
  name             = "${local.vm_prefix}-postgres-${count.index + 1}"
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

  # Data disk for PostgreSQL
  disk {
    label            = "disk1"
    size             = var.postgres_data_disk_size_gb
    thin_provisioned = true
    unit_number      = 1
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template_ubuntu.id

    customize {
      linux_options {
        host_name = "${local.vm_prefix}-postgres-${count.index + 1}"
        domain    = var.domain
      }

      network_interface {
        ipv4_address = cidrhost(var.network_cidr, 30 + count.index)
        ipv4_netmask = var.netmask
      }

      ipv4_gateway    = var.gateway
      dns_server_list = var.dns_servers
    }
  }

  annotation = "${local.notes_tags}\nRole: PostgreSQL Node\nCluster: Patroni\nInstance: ${count.index + 1}"
}

# =============================================================================
# MONITORING VM (Prometheus + Grafana)
# =============================================================================

resource "vsphere_virtual_machine" "monitoring" {
  count            = var.enable_monitoring ? 1 : 0
  name             = "${local.vm_prefix}-monitoring"
  resource_pool_id = vsphere_resource_pool.migration_pool.id
  datastore_id     = data.vsphere_datastore.datastore.id
  folder           = vsphere_folder.vm_folder.path

  num_cpus = var.monitoring_vcpu
  memory   = var.monitoring_memory_mb
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

  # Data disk for metrics storage
  disk {
    label            = "disk1"
    size             = 500
    thin_provisioned = true
    unit_number      = 1
  }

  clone {
    template_uuid = data.vsphere_virtual_machine.template_ubuntu.id

    customize {
      linux_options {
        host_name = "${local.vm_prefix}-monitoring"
        domain    = var.domain
      }

      network_interface {
        ipv4_address = cidrhost(var.network_cidr, 40)
        ipv4_netmask = var.netmask
      }

      ipv4_gateway    = var.gateway
      dns_server_list = var.dns_servers
    }
  }

  annotation = "${local.notes_tags}\nRole: Monitoring (Prometheus/Grafana)"
}

# =============================================================================
# DOMAIN CONTROLLERS
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
        computer_name  = "${local.vm_prefix}-src-dc"
        workgroup      = "WORKGROUP"
        admin_password = var.admin_password
      }

      network_interface {
        ipv4_address = cidrhost(var.network_cidr, 100)
        ipv4_netmask = var.netmask
      }

      ipv4_gateway    = var.gateway
      dns_server_list = concat([cidrhost(var.network_cidr, 100)], var.dns_servers)
    }
  }

  annotation = "${local.notes_tags}\nRole: Source Domain Controller\nDomain: ${var.source_domain_fqdn}"
}

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
        computer_name  = "${local.vm_prefix}-tgt-dc"
        workgroup      = "WORKGROUP"
        admin_password = var.admin_password
      }

      network_interface {
        ipv4_address = cidrhost(var.network_cidr, 110)
        ipv4_netmask = var.netmask
      }

      ipv4_gateway    = var.gateway
      dns_server_list = concat([cidrhost(var.network_cidr, 110)], var.dns_servers)
    }
  }

  annotation = "${local.notes_tags}\nRole: Target Domain Controller\nDomain: ${var.target_domain_fqdn}"
}


