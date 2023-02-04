locals {
  compute_network_names_0 = [
    for network in var.compute_networks : {
      name = coalesce(
        # If network name was explicitly provided, use as is
        network.name,
        # If network name postfix disable was set to true, use network name prefix as is
        network.name_postfix_disable != null ? network.name_postfix_disable == true ? network.name_prefix : null : null,
        # Try returning "network name-network name postfix", return null if 
        # one or the other wasn't provided
        try(
          "${network.name_prefix}-${network.name_postfix}",
          null
        ),
        # Finally attempt to return "network name-default postfix"
        try(
          "${network.name_prefix}-network",
          null
        )
      )
      compute_subnetworks = network.compute_subnetworks == null ? [] : network.compute_subnetworks
    }
  ]
  compute_network_names_1 = [
    for network in local.compute_network_names_0 : {
      name = network.name
      compute_subnetwork_names = network.compute_subnetworks == null ? [] : [
        for idx, subnetwork in network.compute_subnetworks : {
          name = coalesce(
            subnetwork.name,
            subnetwork.name_prefix_disable != null
            ? subnetwork.name_prefix_disable == true
            ? try("${network.name}-${idx}", null)
            : try("${network.name}-${subnetwork.name_prefix}-${idx}", null)
            : try("${network.name}-${subnetwork.name_prefix}-${idx}", null),
            try("${network.name}-subnet-${idx}", null)
          )
          secondary_ip_ranges = subnetwork.secondary_ip_ranges
        }
      ]
    }
  ]
  compute_network_names = [
    for network in local.compute_network_names_1 : {
      name = network.name
      compute_subnetwork_names = network.compute_subnetwork_names == null ? [] : [
        for idx, subnetwork in network.compute_subnetwork_names : {
          name = subnetwork.name
          compute_subnetwork_secondary_range_names = subnetwork.secondary_ip_ranges == null ? [] : [
            for idx, secondary_range in subnetwork.secondary_ip_ranges : {
              name = coalesce(
                secondary_range.range_name,
                secondary_range.range_name_prefix_disable != null
                ? secondary_range.range_name_prefix_disable == true
                ? try("${subnetwork.name}-${idx}", null)
                : try("${subnetwork.name}-${secondary_range.range_name_prefix}-${idx}", null)
                : try("${subnetwork.name}-${secondary_range.range_name_prefix}-${idx}", null),
                try("${subnetwork.name}-secondary-range-${idx}", null)
              )
            }
          ]
        }
      ]
    }
  ]
}

