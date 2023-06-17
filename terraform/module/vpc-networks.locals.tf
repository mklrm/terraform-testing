locals {
  compute_networks_0 = [
    # TODO Set unset booleans to a default value here, use that to simplify later code
    for network in var.compute_networks : {
      project                          = try(network.project, var.default_project)
      auto_create_subnetworks          = network.auto_create_subnetworks
      add_allow_internal_firewall_rule = network.add_allow_internal_firewall_rule
      add_iap_firewall_rule            = network.add_iap_firewall_rule
      tags                             = network.tags

      name = coalesce(
        network.name,
        network.name_postfix_disable != null ? network.name_postfix_disable == true ? network.name_prefix : null : null,
        try(
          "${network.name_prefix}-${network.name_postfix}",
          null
        ),
        try(
          "${network.name_prefix}-${var.compute_network_default_postfix}",
          null
        )
      )

      compute_network_peerings = network.compute_network_peerings != null ? network.compute_network_peerings : []

      compute_subnetworks = network.compute_subnetworks == null ? [] : [
        for subnetwork in network.compute_subnetworks : {
          name                 = subnetwork.name
          name_postfix         = subnetwork.name_postfix
          name_postfix_disable = subnetwork.name_postfix_disable != null ? subnetwork.name_postfix_disable : false
          name_idx_disable     = subnetwork.name_idx_disable != null ? subnetwork.name_idx_disable : false
          project = (
            subnetwork.project != null
            ? subnetwork.project
            : network.project != null
            ? network.project
            : var.default_project
          )
          region        = subnetwork.region != null ? subnetwork.region : var.default_region
          ip_cidr_range = subnetwork.ip_cidr_range
          instance_attach_tags = (
            subnetwork.instance_attach_tags == null
            ? []
            : subnetwork.instance_attach_tags
          )
          #secondary_ip_ranges = subnetwork.secondary_ip_ranges
          secondary_ip_ranges = subnetwork.secondary_ip_ranges == null ? [] : [
            for secondary_range in subnetwork.secondary_ip_ranges : {
              range_name                 = secondary_range.range_name
              range_name_postfix         = secondary_range.range_name_postfix
              range_name_postfix_disable = secondary_range.range_name_postfix_disable != null ? secondary_range.range_name_postfix_disable : false
              range_name_idx_disable     = secondary_range.range_name_idx_disable != null ? secondary_range.range_name_idx_disable : false
              ip_cidr_range              = secondary_range.ip_cidr_range
            }
          ]
        }
      ]

      cloud_nats = network.cloud_nats == null ? [] : [
        for cloud_nat in network.cloud_nats : {
          name                 = cloud_nat.name
          name_postfix         = cloud_nat.name_postfix
          name_postfix_disable = cloud_nat.name_postfix_disable != null ? cloud_nat.name_postfix_disable : false
          name_idx_disable     = cloud_nat.name_idx_disable != null ? cloud_nat.name_idx_disable : false
          region               = cloud_nat.region != null ? cloud_nat.region : var.default_region
          project              = cloud_nat.project != null ? cloud_nat.project : var.default_project
          router               = cloud_nat.router
        }
      ]
    }
  ]

  compute_networks_1 = [
    for network in local.compute_networks_0 : {
      name                             = network.name
      project                          = network.project
      auto_create_subnetworks          = network.auto_create_subnetworks
      add_allow_internal_firewall_rule = network.add_allow_internal_firewall_rule
      add_iap_firewall_rule            = network.add_iap_firewall_rule
      tags                             = network.tags

      compute_subnetworks = network.compute_subnetworks == null ? [] : [
        for idx, subnetwork in network.compute_subnetworks : {
          project              = subnetwork.project
          region               = subnetwork.region
          ip_cidr_range        = subnetwork.ip_cidr_range
          instance_attach_tags = subnetwork.instance_attach_tags
          name = coalesce(
            subnetwork.name,
            subnetwork.name_postfix_disable == true
            ? try("${network.name}", null)
            : try("${network.name}-${subnetwork.name_postfix}", null),
            try("${network.name}-${var.compute_subnetwork_default_postfix}", null)
          )
          name_explicitly_set = subnetwork.name != null ? true : false
          name_idx_disable    = subnetwork.name_idx_disable
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
            cloud_nat.name_postfix_disable == true
            ? try("${network.name}", null)
            : try("${network.name}-${cloud_nat.name_postfix}", null),
            try("${network.name}-${var.cloud_nat_default_postfix}", null)
          )
          name_explicitly_set = cloud_nat.name != null ? true : false
          name_idx_disable    = cloud_nat.name_idx_disable
        }
      ]

      compute_network_peerings = network.compute_network_peerings == null ? [] : [
        for idx, peering in network.compute_network_peerings : {
          name                 = peering.name
          name_prefix          = peering.name_prefix
          name_prefix_disable  = peering.name_prefix_disable
          name_postfix         = peering.name_postfix
          name_postfix_disable = peering.name_postfix_disable
          name_idx_enable      = peering.name_idx_enable

          peer_network_name = (
            peering.peer_network_name != null
            ? peering.peer_network_name
            : peering.peer_network_tags != null
            ? flatten(flatten([
              # NOTE One would hope there's a better way of doing this
              for tag in peering.peer_network_tags : {
                network = [
                  for net in local.compute_networks_0 : {
                    net = contains(net.tags, tag) ? net.name : null
                  } if net.name != network.name
                ]
              }
            ][*]["network"][*]["net"][*]))[0]
            : null
          )

          peer_network_name_prefix            = peering.peer_network_name_prefix
          peer_network_name_postfix           = peering.peer_network_name_postfix
          peer_network_name_postfix_disable   = peering.peer_network_name_postfix_disable
          peer_network_tags                   = peering.peer_network_tags
          export_custom_routes                = peering.export_custom_routes
          import_custom_routes                = peering.import_custom_routes
          export_subnet_routes_with_public_ip = peering.export_subnet_routes_with_public_ip
          import_subnet_routes_with_public_ip = peering.import_subnet_routes_with_public_ip
        }
      ]
    }
  ]

  compute_networks_2 = [
    for network in local.compute_networks_1 : {
      name                             = network.name
      project                          = network.project
      auto_create_subnetworks          = network.auto_create_subnetworks
      add_allow_internal_firewall_rule = network.add_allow_internal_firewall_rule
      add_iap_firewall_rule            = network.add_iap_firewall_rule
      tags                             = network.tags

      compute_subnetworks = network.compute_subnetworks == null ? [] : [
        for idx, subnetwork in network.compute_subnetworks : {
          name = (
            subnetwork.name_explicitly_set == true
            ? subnetwork.name
            : subnetwork.name_idx_disable == true
            ? subnetwork.name
            : "${subnetwork.name}-${idx}"
          )
          project              = network.project
          ip_cidr_range        = subnetwork.ip_cidr_range
          region               = subnetwork.region
          instance_attach_tags = subnetwork.instance_attach_tags
          secondary_ip_ranges = subnetwork.secondary_ip_ranges == null ? [] : [
            for idx, secondary_range in subnetwork.secondary_ip_ranges : {
              range_name = coalesce(
                secondary_range.range_name,
                secondary_range.range_name_postfix_disable == true
                ? try("${subnetwork.name}", null)
                : try("${subnetwork.name}-${secondary_range.range_name_postfix}", null),
                try("${subnetwork.name}-${var.compute_subnetwork_secondary_range_default_postfix}", null)
              )
              name_explicitly_set    = secondary_range.range_name != null ? true : false
              range_name_idx_disable = secondary_range.range_name_idx_disable
              ip_cidr_range          = secondary_range.ip_cidr_range
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
            : "-${var.compute_network_peering_default_postfix}"
            }${
            peering.name_idx_enable != null
            ? peering.name_idx_enable == true
            ? "-${idx}"
            : ""
            # peering.name_idx_enable == false:
            : ""
          }"

          peer_network_tags = peering.peer_network_tags

          peer_network_name = coalesce(
            peering.peer_network_name,
            (
              peering.peer_network_name_postfix_disable != null
              ? peering.peer_network_name_postfix_disable == true
              ? peering.peer_network_name_prefix
              : null
              : null
            ),
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

      cloud_nats = [
        for idx, cloud_nat in network.cloud_nats : {
          project = cloud_nat.project
          router  = cloud_nat.router
          region  = cloud_nat.region
          name = (
            cloud_nat.name_explicitly_set == true
            ? cloud_nat.name
            : cloud_nat.name_idx_disable == true
            ? cloud_nat.name
            : "${cloud_nat.name}-${idx}"
          )
        }
      ]

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

  compute_networks_3 = [
    for network in local.compute_networks_2 : {
      name                             = network.name
      project                          = network.project
      auto_create_subnetworks          = network.auto_create_subnetworks
      add_allow_internal_firewall_rule = network.add_allow_internal_firewall_rule
      add_iap_firewall_rule            = network.add_iap_firewall_rule
      tags                             = network.tags
      compute_subnetworks              = network.compute_subnetworks

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
          peer_network_tags = peering.peer_network_tags
          peer_network_name = peering.peer_network_name
        }
      ]

      cloud_nats                    = network.cloud_nats
      autogenerated_compute_routers = network.autogenerated_compute_routers
    }
  ]

  compute_networks = [
    for network in local.compute_networks_3 : {
      name                             = network.name
      project                          = network.project
      auto_create_subnetworks          = network.auto_create_subnetworks
      add_allow_internal_firewall_rule = network.add_allow_internal_firewall_rule
      add_iap_firewall_rule            = network.add_iap_firewall_rule
      tags                             = network.tags

      compute_subnetworks = network.compute_subnetworks == null ? [] : [
        for idx, subnetwork in network.compute_subnetworks : {
          name                 = subnetwork.name
          project              = subnetwork.project
          ip_cidr_range        = subnetwork.ip_cidr_range
          region               = subnetwork.region
          instance_attach_tags = subnetwork.instance_attach_tags
          #compute_subnetwork_secondary_ranges = subnetwork.secondary_ip_ranges == null ? [] : [
          secondary_ip_ranges = subnetwork.secondary_ip_ranges == null ? [] : [
            for idx, secondary_range in subnetwork.secondary_ip_ranges : {
              range_name = (
                secondary_range.name_explicitly_set == true
                ? secondary_range.range_name
                : secondary_range.range_name_idx_disable == true
                ? secondary_range.range_name
                : "${secondary_range.range_name}-${idx}"
              )
              ip_cidr_range = secondary_range.ip_cidr_range
            }
          ]
        }
      ]

      compute_network_peerings      = network.compute_network_peerings
      cloud_nats                    = network.cloud_nats
      autogenerated_compute_routers = network.autogenerated_compute_routers
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
        #secondary_ip_ranges  = coalesce(subnetwork.compute_subnetwork_secondary_ranges, [])
        # TODO Prtty sure the coalsece() is not needed here at this point
        secondary_ip_ranges = coalesce(subnetwork.secondary_ip_ranges, [])
      }
    ]
  ])

  compute_network_peerings = flatten([
    for network in local.compute_networks : [
      for peering in network.compute_network_peerings : {
        name                                = peering.name
        network_name                        = network.name
        peer_network_tags                   = peering.peer_network_tags
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
