terraform {
  required_version = ">= 0.14.0"
  required_providers {
    fortimanager = {
      source  = "fortinetdev/fortimanager"
      version = "~>1.3.5"
    }
  }
}

/**************FTNT**************
Firewall addresses that will be created/deleted based on the services
***************FTNT*************/
resource "fortimanager_object_firewall_address" "consul_service" {
  for_each = var.services

  scopetype = var.scopetype
  adom      = var.adom
  name      = "${var.addrname_prefix}${each.value.id}${var.addrname_sufix}"
  subnet    = [each.value.address, var.net_mask]
  obj_type  = "ip"
  type      = "ipmask"

  lifecycle {
    create_before_destroy = true
  }
}

/**************FTNT**************
Firewall address groups that will be created/updated based on the variable of addrgrp_name_map and services
***************FTNT*************/
resource "fortimanager_object_firewall_addrgrp" "consul_service" {
  for_each = var.addrgrp_name_map

  scopetype = var.scopetype
  adom      = var.adom
  name      = each.key
  member    = length(setintersection(keys(local.consul_services), var.addrgrp_name_map[each.key])) == 0 ? ["none"] : flatten([
                for s_name in setintersection(keys(local.consul_services), var.addrgrp_name_map[each.key]) : [
                  for k, v in local.consul_services[s_name] : "${var.addrname_prefix}${v.id}${var.addrname_sufix}"
                ]
              ])

  depends_on = [
    fortimanager_object_firewall_address.consul_service
  ]
}

/**************FTNT**************
Execute this resource when variable install_package set to 'Yes'
***************FTNT*************/
resource "fortimanager_securityconsole_install_package" "trname" {
  for_each = local.install_package

  fmgadom        = var.adom
  force_recreate = uuid()
  flags          = ["none"]
  pkg            = var.package

  depends_on = [
    fortimanager_object_firewall_addrgrp.consul_service
  ]
}

locals {
  install_package = var.install_package == "Yes" ? { "install_package" = "Yes" } : {}
  consul_services = {
    for id, s in var.services : s.name => s...
  }
}