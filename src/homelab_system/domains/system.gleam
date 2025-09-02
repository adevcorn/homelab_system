//// Homelab System Domain Module
////
//// This module defines the core business domain logic for the homelab system.
//// It contains domain entities, value objects, and business rules.
////
//// Features:
//// - System domain entities and aggregates
//// - Business rules and validations
//// - Domain events and commands
//// - Value objects for type safety

import gleam/dict.{type Dict}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string

/// System node entity
pub type SystemNode {
  SystemNode(
    id: NodeId,
    name: String,
    host: String,
    port: Int,
    status: NodeStatus,
    capabilities: List(Capability),
    metadata: Dict(String, String),
    last_seen: Int,
  )
}

/// Node identifier value object
pub type NodeId {
  NodeId(value: String)
}

/// Node status enumeration
pub type NodeStatus {
  Online
  Offline
  Maintenance
  Unhealthy
}

/// System capability
pub type Capability {
  ComputeCapability(cpu_cores: Int, memory_gb: Int)
  StorageCapability(capacity_gb: Int, storage_type: String)
  NetworkCapability(bandwidth_mbps: Int, interfaces: List(String))
  ServiceCapability(service_name: String, version: String)
}

/// Cluster aggregate
pub type Cluster {
  Cluster(
    id: ClusterId,
    name: String,
    nodes: List(SystemNode),
    leader: Option(NodeId),
    state: ClusterState,
    configuration: ClusterConfig,
  )
}

/// Cluster identifier value object
pub type ClusterId {
  ClusterId(value: String)
}

/// Cluster state
pub type ClusterState {
  Forming
  Active
  Degraded
  Unavailable
}

/// Cluster configuration
pub type ClusterConfig {
  ClusterConfig(
    min_nodes: Int,
    max_nodes: Int,
    replication_factor: Int,
    auto_healing: Bool,
  )
}

/// Domain events
pub type DomainEvent {
  NodeJoinedEvent(node_id: NodeId, cluster_id: ClusterId)
  NodeLeftEvent(node_id: NodeId, cluster_id: ClusterId, reason: String)
  NodeStatusChangedEvent(
    node_id: NodeId,
    old_status: NodeStatus,
    new_status: NodeStatus,
  )
  ClusterStateChangedEvent(
    cluster_id: ClusterId,
    old_state: ClusterState,
    new_state: ClusterState,
  )
  LeaderElectedEvent(cluster_id: ClusterId, leader_id: NodeId)
  ServiceDeployedEvent(node_id: NodeId, service_name: String, version: String)
}

/// Domain commands
pub type DomainCommand {
  AddNodeCommand(node: SystemNode)
  RemoveNodeCommand(node_id: NodeId)
  UpdateNodeStatusCommand(node_id: NodeId, status: NodeStatus)
  CreateClusterCommand(name: String, config: ClusterConfig)
  DestroyClusterCommand(cluster_id: ClusterId)
  ElectLeaderCommand(cluster_id: ClusterId)
}

/// Command result
pub type CommandResult {
  CommandSuccess(events: List(DomainEvent))
  CommandFailure(error: String)
}

/// Create a new system node
pub fn create_system_node(
  id: String,
  name: String,
  host: String,
  port: Int,
) -> Result(SystemNode, String) {
  case validate_node_id(id), validate_host(host), validate_port(port) {
    Ok(_), Ok(_), Ok(_) -> {
      Ok(SystemNode(
        id: NodeId(id),
        name: name,
        host: host,
        port: port,
        status: Offline,
        capabilities: [],
        metadata: dict.new(),
        last_seen: 0,
      ))
    }
    Error(e), _, _ -> Error("Invalid node ID: " <> e)
    _, Error(e), _ -> Error("Invalid host: " <> e)
    _, _, Error(e) -> Error("Invalid port: " <> e)
  }
}

/// Create a new cluster
pub fn create_cluster(
  id: String,
  name: String,
  config: ClusterConfig,
) -> Result(Cluster, String) {
  case validate_cluster_id(id) {
    Ok(_) -> {
      Ok(Cluster(
        id: ClusterId(id),
        name: name,
        nodes: [],
        leader: None,
        state: Forming,
        configuration: config,
      ))
    }
    Error(e) -> Error("Invalid cluster ID: " <> e)
  }
}

/// Add a node to a cluster
pub fn add_node_to_cluster(
  cluster: Cluster,
  node: SystemNode,
) -> Result(#(Cluster, List(DomainEvent)), String) {
  case list.length(cluster.nodes) >= cluster.configuration.max_nodes {
    True -> Error("Cluster has reached maximum node capacity")
    False -> {
      let updated_nodes = [node, ..cluster.nodes]
      let updated_cluster = Cluster(..cluster, nodes: updated_nodes)
      let events = [NodeJoinedEvent(node.id, cluster.id)]
      Ok(#(updated_cluster, events))
    }
  }
}

/// Remove a node from a cluster
pub fn remove_node_from_cluster(
  cluster: Cluster,
  node_id: NodeId,
) -> Result(#(Cluster, List(DomainEvent)), String) {
  let remaining_nodes =
    list.filter(cluster.nodes, fn(node) { node.id != node_id })

  case list.length(remaining_nodes) < cluster.configuration.min_nodes {
    True -> Error("Removing node would violate minimum node requirement")
    False -> {
      let updated_cluster = Cluster(..cluster, nodes: remaining_nodes)
      let events = [NodeLeftEvent(node_id, cluster.id, "manual_removal")]
      Ok(#(updated_cluster, events))
    }
  }
}

/// Update node status
pub fn update_node_status(
  node: SystemNode,
  new_status: NodeStatus,
) -> #(SystemNode, List(DomainEvent)) {
  let old_status = node.status
  let updated_node = SystemNode(..node, status: new_status)
  let events = case old_status != new_status {
    True -> [NodeStatusChangedEvent(node.id, old_status, new_status)]
    False -> []
  }
  #(updated_node, events)
}

/// Check cluster health and update state
pub fn check_cluster_health(cluster: Cluster) -> #(Cluster, List(DomainEvent)) {
  let online_nodes =
    list.filter(cluster.nodes, fn(node) {
      case node.status {
        Online -> True
        _ -> False
      }
    })

  let online_count = list.length(online_nodes)
  let total_count = list.length(cluster.nodes)

  let new_state = case online_count, total_count {
    0, _ -> Unavailable
    count, total if count == total -> Active
    count, total if count >= total / 2 -> Degraded
    _, _ -> Unavailable
  }

  let events = case cluster.state != new_state {
    True -> [ClusterStateChangedEvent(cluster.id, cluster.state, new_state)]
    False -> []
  }

  let updated_cluster = Cluster(..cluster, state: new_state)
  #(updated_cluster, events)
}

/// Elect a leader for the cluster
pub fn elect_leader(
  cluster: Cluster,
) -> Result(#(Cluster, List(DomainEvent)), String) {
  let online_nodes =
    list.filter(cluster.nodes, fn(node) {
      case node.status {
        Online -> True
        _ -> False
      }
    })

  case online_nodes {
    [] -> Error("No online nodes available for leader election")
    [first_node, ..] -> {
      let updated_cluster = Cluster(..cluster, leader: Some(first_node.id))
      let events = [LeaderElectedEvent(cluster.id, first_node.id)]
      Ok(#(updated_cluster, events))
    }
  }
}

// Validation functions

/// Validate node ID format
fn validate_node_id(id: String) -> Result(Nil, String) {
  case string.length(id) {
    0 -> Error("Node ID cannot be empty")
    length if length > 64 -> Error("Node ID too long (max 64 characters)")
    _ -> Ok(Nil)
  }
}

/// Validate cluster ID format
fn validate_cluster_id(id: String) -> Result(Nil, String) {
  case string.length(id) {
    0 -> Error("Cluster ID cannot be empty")
    length if length > 64 -> Error("Cluster ID too long (max 64 characters)")
    _ -> Ok(Nil)
  }
}

/// Validate host address
fn validate_host(host: String) -> Result(Nil, String) {
  case string.length(host) {
    0 -> Error("Host cannot be empty")
    _ -> Ok(Nil)
    // TODO: Implement proper hostname/IP validation
  }
}

/// Validate port number
fn validate_port(port: Int) -> Result(Nil, String) {
  case port {
    p if p <= 0 -> Error("Port must be positive")
    p if p > 65_535 -> Error("Port must be <= 65535")
    _ -> Ok(Nil)
  }
}

// Helper functions for working with domain entities

/// Find node by ID in a cluster
pub fn find_node(
  cluster: Cluster,
  node_id: NodeId,
) -> Result(SystemNode, String) {
  case list.find(cluster.nodes, fn(node) { node.id == node_id }) {
    Ok(node) -> Ok(node)
    Error(_) -> Error("Node not found")
  }
}

/// Get cluster statistics
pub fn get_cluster_stats(cluster: Cluster) -> Dict(String, String) {
  let total_nodes = list.length(cluster.nodes)
  let online_nodes =
    list.length(
      list.filter(cluster.nodes, fn(node) {
        case node.status {
          Online -> True
          _ -> False
        }
      }),
    )

  dict.new()
  |> dict.insert("total_nodes", int_to_string(total_nodes))
  |> dict.insert("online_nodes", int_to_string(online_nodes))
  |> dict.insert("state", cluster_state_to_string(cluster.state))
  |> dict.insert("has_leader", case cluster.leader {
    Some(_) -> "true"
    None -> "false"
  })
}

/// Convert cluster state to string
fn cluster_state_to_string(state: ClusterState) -> String {
  case state {
    Forming -> "forming"
    Active -> "active"
    Degraded -> "degraded"
    Unavailable -> "unavailable"
  }
}

/// Convert node status to string
pub fn node_status_to_string(status: NodeStatus) -> String {
  case status {
    Online -> "online"
    Offline -> "offline"
    Maintenance -> "maintenance"
    Unhealthy -> "unhealthy"
  }
}

/// Helper to convert int to string (placeholder)
fn int_to_string(value: Int) -> String {
  case value {
    0 -> "0"
    1 -> "1"
    2 -> "2"
    3 -> "3"
    4 -> "4"
    5 -> "5"
    _ -> "many"
    // TODO: Implement proper int to string conversion
  }
}
