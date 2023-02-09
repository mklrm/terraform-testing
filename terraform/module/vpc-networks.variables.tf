# TODO Add name prefix and postfix variables with defaults
# TODO Add a separate compute_networks name_prefix_disable_propagate that compute_networks will use

variable "compute_network_default_postfix" {
  default     = "network"
  description = "Default postfix for VPC names"
  type        = string
}

variable "compute_subnetwork_default_prefix" {
  default     = "snet"
  description = "Default prefix for subnetwork names"
  type        = string
}

variable "compute_network_peering_default_postfix" {
  default     = "peering"
  description = "Default prefix for VPC peerings"
  type        = string
}

variable "compute_subnetwork_secondary_range_default_postfix" {
  default     = "secondary-range"
  description = "Default prefix for subnetwork secondary range names"
  type        = string
}

variable "compute_networks" {
  default     = []
  description = "Compute networks and networking connected resources"
  type = list(object({
    # TODO Add a name_prefix_disable_propagate boolean that applies the setting to sub objects
    # TODO Add a boolean to determine if a random string will be baked into names
    # TODO Test name generation thoroughly
    # TODO Might want to add a boolean for adding a number to network names, 
    # will have to take matching prefixes into account (same prefixes would usually 
    # likely be part of the same sequence)
    name                    = optional(string)
    name_prefix             = optional(string)
    name_postfix            = optional(string)
    name_postfix_disable    = optional(bool)
    project                 = optional(string)
    auto_create_subnetworks = optional(bool)
    add_iap_firewall_rule   = optional(bool)
    compute_subnetworks = optional(list(object({
      name                = optional(string)
      name_prefix         = optional(string)
      name_prefix_disable = optional(bool)
      ip_cidr_range       = optional(string) # TODO Pull off of a list if user doesn't pass this
      region              = optional(string)
      secondary_ip_ranges = optional(list(object({
        range_name                = optional(string)
        range_name_prefix         = optional(string)
        range_name_prefix_disable = optional(bool)
        ip_cidr_range             = optional(string) # TODO Pull off of a list if user doesn't pass this
      })))
    })))
    compute_network_peerings = optional(list(object({
      name                                = optional(string)
      name_prefix                         = optional(string)
      name_prefix_disable                 = optional(bool)
      name_postfix                        = optional(string)
      name_postfix_disable                = optional(bool)
      name_idx_enable                     = optional(bool)
      peer_network_name                   = optional(string)
      peer_network_name_prefix            = optional(string)
      peer_network_name_postfix           = optional(string)
      peer_network_name_postfix_disable   = optional(bool)
      export_custom_routes                = optional(bool)
      import_custom_routes                = optional(bool)
      export_subnet_routes_with_public_ip = optional(bool)
      import_subnet_routes_with_public_ip = optional(bool)
    })))
    compute_router_nats = optional(list(object({
      # TODO Automatically create cloud router by default, 
      # keeping in mind that if there already is one in the 
      # network/region you can use that but not create 
      # another one
      name                               = optional(string)
      name_prefix                        = optional(string)
      name_prefix_disable                = optional(bool)
      project                            = optional(string)
      router                             = optional(string)
      region                             = optional(string)
      nat_ip_allocate_option             = optional(string)
      source_subnetwork_ip_ranges_to_nat = optional(string)

      log_config = optional(list(object({
        enable = optional(bool)
        filter = optional(string)
      })))
    })))
  }))
}

#resource "google_compute_router" "router" {
#  name    = "my-router"
#  region  = google_compute_subnetwork.subnet.region
#  network = google_compute_network.net.id
#
#  bgp {
#    asn = 64514
#  }
#}
#
#resource "google_compute_router_nat" "nat" {
#  name                               = "my-router-nat"
#  router                             = google_compute_router.router.name
#  region                             = google_compute_router.router.region
#  nat_ip_allocate_option             = "AUTO_ONLY"
#  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
#
#  log_config {
#    enable = true
#    filter = "ERRORS_ONLY"
#  }
#}
