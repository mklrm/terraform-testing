locals {
  compute_networks_0 = [
    for network in var.compute_networks : {
      project                 = try(network.project, var.default_project)
      auto_create_subnetworks = network.auto_create_subnetworks
      add_iap_firewall_rule   = network.add_iap_firewall_rule

      name = coalesce(
        # If network name was explicitly provided, use as is
        network.name,
        # If network name postfix disable was set to true, use network name prefix as is
        network.name_postfix_disable != null ? network.name_postfix_disable == true ? network.name_prefix : null : null,
        # Try returning "network name-network name postfix", return null if 
        # one or the other wasn't provided
        # TODO Use try(network.name_postfix, "network") to generage the postfix and 
        # get rid of the second try
        # - Or not, because this is terraform and it doesn't work, maybe try again
        #   at some point...
        try(
          "${network.name_prefix}-${network.name_postfix}",
          null
        ),
        # Finally attempt to return "network name-default postfix"
        try(
          "${network.name_prefix}-${var.compute_network_default_postfix}",
          null
        )
      )

      compute_network_peerings = try(network.compute_network_peerings, [])
      compute_subnetworks      = try(network.compute_subnetworks, [])

      cloud_nats = network.cloud_nats == null ? [] : [
        for cloud_nat in network.cloud_nats : {
          name                 = cloud_nat.name
          name_postfix         = cloud_nat.name_postfix
          name_postfix_disable = cloud_nat.name_postfix_disable
          region               = cloud_nat.region != null ? cloud_nat.region : var.default_region
          project              = cloud_nat.project != null ? cloud_nat.project : var.default_project
          router               = cloud_nat.router
        }
      ]
    }
  ]

  compute_networks_1 = [
    for network in local.compute_networks_0 : {
      name                    = network.name
      project                 = network.project
      auto_create_subnetworks = network.auto_create_subnetworks
      add_iap_firewall_rule   = network.add_iap_firewall_rule

      compute_subnetworks = network.compute_subnetworks == null ? [] : [
        for idx, subnetwork in network.compute_subnetworks : {
          project       = network.project != null ? network.project : var.default_project
          region        = subnetwork.region != null ? subnetwork.region : var.default_region
          ip_cidr_range = subnetwork.ip_cidr_range
          instance_attach_tags = (
            subnetwork.instance_attach_tags == null
            ? []
            : subnetwork.instance_attach_tags
          )
          name = coalesce(
            subnetwork.name,
            subnetwork.name_postfix_disable != null
            ? subnetwork.name_postfix_disable == true
            ? try("${network.name}-${idx}", null)
            : try("${network.name}-${subnetwork.name_postfix}-${idx}", null)
            : try("${network.name}-${subnetwork.name_postfix}-${idx}", null),
            try("${network.name}-${var.compute_subnetwork_default_postfix}-${idx}", null)
          )
          secondary_ip_ranges = subnetwork.secondary_ip_ranges
        }
      ]

      autogenerated_compute_routers = network.cloud_nats == null ? [] : [
        # Select Cloud Nats that do not have a router explicitly set
        for cloud_nat in network.cloud_nats : cloud_nat if cloud_nat.router == null
      ]

      cloud_nats = network.cloud_nats == null ? [] : [
        for idx, cloud_nat in network.cloud_nats : {
          project = cloud_nat.project
          router = (
            cloud_nat.router != null
            ? cloud_nat.router
            : coalesce(
              try("${network.name}-${cloud_nat.region}-router", null),
              try("${network.name}-${var.default_region}-router", null)
            )
          )
          region = cloud_nat.region
          name = coalesce(
            cloud_nat.name,
            cloud_nat.name_postfix_disable != null
            ? cloud_nat.name_postfix_disable == true
            ? try("${network.name}-${idx}", null)
            : try("${network.name}-${cloud_nat.name_postfix}-${idx}", null)
            : try("${network.name}-${cloud_nat.name_postfix}-${idx}", null),
            try("${network.name}-${var.cloud_nat_default_postfix}-${idx}", null)
          )
        }
      ]

      compute_network_peerings = network.compute_network_peerings == null ? [] : [
        for idx, peering in network.compute_network_peerings : {
          export_custom_routes                = peering.export_custom_routes
          import_custom_routes                = peering.import_custom_routes
          export_subnet_routes_with_public_ip = peering.export_subnet_routes_with_public_ip
          import_subnet_routes_with_public_ip = peering.import_subnet_routes_with_public_ip
          name                                = peering.name
          name_prefix_disable                 = peering.name_prefix_disable
          name_postfix_disable                = peering.name_postfix_disable
          name_idx_enable                     = peering.name_idx_enable
          # TODO It would simplify lots of things if I was able to get around 
          # having to check if a variable is null before checking what the 
          # value is like I do here:
          name_prefix = (
            peering.name_prefix_disable != null
            ? peering.name_prefix_disable == true
            ? ""
            : coalesce(
              try("${peering.name_prefix}", null),
              try("${network.name}-to-${
                coalesce(
                  peering.peer_network_name,
                  peering.peer_network_name_postfix_disable != null ? peering.peer_network_name_postfix_disable == true ? peering.peer_network_name_prefix : null : null,
                  # TODO Merge these two tries by inlining one in the other:
                  try(
                    "${peering.peer_network_name_prefix}-${peering.peer_network_name_postfix}",
                    null
                  ),
                  try(
                    "${peering.peer_network_name_prefix}-${var.compute_network_default_postfix}",
                    null
                  )
                )
              }", null),
            )
            : coalesce(
              try("${peering.name_prefix}", null),
              try("${network.name}-to-${
                coalesce(
                  peering.peer_network_name,
                  peering.peer_network_name_postfix_disable != null ? peering.peer_network_name_postfix_disable == true ? peering.peer_network_name_prefix : null : null,
                  # TODO Merge these two tries by inlining one in the other:
                  try(
                    "${peering.peer_network_name_prefix}-${peering.peer_network_name_postfix}",
                    null
                  ),
                  try(
                    "${peering.peer_network_name_prefix}-${var.compute_network_default_postfix}",
                    null
                  )
                )
              }", null),
            )
          )

          name_postfix = "${
            peering.name_postfix_disable != null
            ? peering.name_postfix_disable == false
            ? peering.name_postfix != null
            ? "-${peering.name_postfix}"
            : "-${var.compute_network_peering_default_postfix}"
            # peering.name_postfix_disable == true:
            : ""
            # peering.name_postfix_disable == null:
            : peering.name_postfix != null
            ? "-${peering.name_postfix}"
            : "${var.compute_network_peering_default_postfix}"
            }${
            peering.name_idx_enable != null
            ? peering.name_idx_enable == true
            ? "-${idx}"
            : ""
            # peering.name_idx_enable == false:
            : ""
          }"

          peer_network_name = coalesce(
            peering.peer_network_name,
            peering.peer_network_name_postfix_disable != null ? peering.peer_network_name_postfix_disable == true ? peering.peer_network_name_prefix : null : null,
            # TODO Merge these two tries by inlining one in the other:
            try(
              "${peering.peer_network_name_prefix}-${peering.peer_network_name_postfix}",
              null
            ),
            try(
              "${peering.peer_network_name_prefix}-${var.compute_network_default_postfix}",
              null
            )
          )
        }
      ]
    }
  ]

  compute_networks = [
    for network in local.compute_networks_1 : {
      name                    = network.name
      project                 = network.project
      auto_create_subnetworks = network.auto_create_subnetworks
      add_iap_firewall_rule   = network.add_iap_firewall_rule

      compute_subnetworks = network.compute_subnetworks == null ? [] : [
        for idx, subnetwork in network.compute_subnetworks : {
          name                 = subnetwork.name
          project              = network.project
          ip_cidr_range        = subnetwork.ip_cidr_range
          region               = subnetwork.region
          instance_attach_tags = subnetwork.instance_attach_tags
          compute_subnetwork_secondary_ranges = subnetwork.secondary_ip_ranges == null ? [] : [
            for idx, secondary_range in subnetwork.secondary_ip_ranges : {
              name = coalesce(
                secondary_range.range_name,
                secondary_range.range_name_postfix_disable != null
                ? secondary_range.range_name_postfix_disable == true
                ? try("${subnetwork.name}-${idx}", null)
                : try("${subnetwork.name}-${secondary_range.range_name_postfix}-${idx}", null)
                : try("${subnetwork.name}-${secondary_range.range_name_postfix}-${idx}", null),
                try("${subnetwork.name}-${var.compute_subnetwork_secondary_range_default_postfix}-${idx}", null)
              )
              ip_cidr_range = secondary_range.ip_cidr_range
            }
          ]
        }
      ]

      compute_network_peerings = network.compute_network_peerings == null ? [] : [
        for idx, peering in network.compute_network_peerings : {
          export_custom_routes                = peering.export_custom_routes
          import_custom_routes                = peering.import_custom_routes
          export_subnet_routes_with_public_ip = peering.export_subnet_routes_with_public_ip
          import_subnet_routes_with_public_ip = peering.import_subnet_routes_with_public_ip
          name = coalesce(
            peering.name,
            # If prefix and postfix are disabled and idx_enable isn't set, return idx:
            peering.name_prefix_disable != null
            ? peering.name_prefix_disable == true
            ? peering.name_postfix_disable != null
            ? peering.name_postfix_disable == true
            ? peering.name_idx_enable == null
            ? "${idx}"
            : null
            : null
            : null
            : null
            : null,
            "${peering.name_prefix}${peering.name_postfix}"
          )
          peer_network_name = peering.peer_network_name
        }
      ]

      cloud_nats = network.cloud_nats

      autogenerated_compute_routers = [
        for idx, router in network.autogenerated_compute_routers : {
          name    = "${network.name}-${router.region}-router"
          project = router.project != null ? router.project : var.default_project
          region  = router.region
          network = network.name
          asn     = 64512 + idx
        }
      ]
    }
  ]

  compute_subnetworks = flatten([
    for network in local.compute_networks : [
      for subnetwork in network.compute_subnetworks : {
        network_name         = network.name
        name                 = subnetwork.name
        project              = network.project
        ip_cidr_range        = subnetwork.ip_cidr_range
        region               = subnetwork.region
        instance_attach_tags = subnetwork.instance_attach_tags
        secondary_ip_ranges  = coalesce(subnetwork.compute_subnetwork_secondary_ranges, [])
      }
    ]
  ])

  compute_network_peerings = flatten([
    for network in local.compute_networks : [
      for peering in network.compute_network_peerings : {
        name                                = peering.name
        network_name                        = network.name
        peer_network_name                   = peering.peer_network_name
        export_custom_routes                = peering.export_custom_routes
        import_custom_routes                = peering.import_custom_routes
        export_subnet_routes_with_public_ip = peering.export_subnet_routes_with_public_ip
        import_subnet_routes_with_public_ip = peering.import_subnet_routes_with_public_ip
      }
    ]
  ])

  autogenerated_compute_routers = flatten([
    for network in local.compute_networks : [
      # Remove duplicate routers based on name:
      values(zipmap(network.autogenerated_compute_routers.*.name, network.autogenerated_compute_routers))
    ]
  ])

  cloud_nats = flatten([
    for network in local.compute_networks : [
      for cloud_nat in network.cloud_nats : {
        project = cloud_nat.project
        name    = cloud_nat.name
        router  = cloud_nat.router
        region  = cloud_nat.region
      }
    ]
  ])
}
