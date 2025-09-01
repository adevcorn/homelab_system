/// Cluster configuration and management module
/// Provides types and functions for managing cluster settings and node interactions

pub type ClusterConfig {
  ClusterConfig(
    cluster_name: String,
    coordinator_port: Int,
    discovery_method: DiscoveryMethod,
    node_capabilities: List(String)
  )
}

pub type DiscoveryMethod {
  Static(nodes: List(String))
  Dns(domain: String)
  Multicast
}

/// Create a new cluster configuration
pub fn new_cluster_config(
  name: String, 
  port: Int, 
  discovery: DiscoveryMethod
) -> ClusterConfig {
  ClusterConfig(
    cluster_name: name,
    coordinator_port: port,
    discovery_method: discovery,
    node_capabilities: []
  )
}