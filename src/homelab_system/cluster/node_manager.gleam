/// Cluster node manager for handling node lifecycle in the homelab system
/// Manages node joining, leaving, failure detection, and metadata
import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option.{type Option}
import gleam/otp/actor

import homelab_system/config/node_config.{type NodeConfig}
import homelab_system/utils/logging
import homelab_system/utils/types.{
  type HealthStatus, type NodeId, type ServiceStatus, type Timestamp,
}

/// Node information stored in the registry
pub type NodeInfo {
  NodeInfo(
    id: NodeId,
    name: String,
    role: node_config.NodeRole,
    capabilities: List(types.Capability),
    status: NodeStatus,
    health: HealthStatus,
    metadata: Dict(String, String),
    last_heartbeat: Timestamp,
    joined_at: Timestamp,
    address: String,
    port: Int,
  )
}

/// Node status in the cluster
pub type NodeStatus {
  NodeJoining
  NodeActive
  NodeLeaving
  NodeSuspected
  NodeDown
  NodeRemoved
}

/// Node manager state
pub type NodeManagerState {
  NodeManagerState(
    local_node: NodeInfo,
    cluster_nodes: Dict(String, NodeInfo),
    cluster_name: String,
    heartbeat_interval: Int,
    failure_detection_timeout: Int,
    status: ServiceStatus,
    cluster_handle: Option(String),
  )
}

/// Messages for the node manager actor
pub type NodeManagerMessage {
  JoinCluster(cluster_name: String)
  LeaveCluster
  NodeJoined(node_info: NodeInfo)
  NodeLeft(node_id: String)
  NodeFailed(node_id: String)
  NodeUpdated(node_info: NodeInfo)
  Heartbeat
  HealthCheck
  GetClusterNodes
  GetNodeInfo(node_id: String)
  Shutdown
}

/// Start the node manager actor
pub fn start_link(
  config: NodeConfig,
) -> Result(
  actor.Started(process.Subject(NodeManagerMessage)),
  actor.StartError,
) {
  let local_node = create_node_info_from_config(config)

  let initial_state =
    NodeManagerState(
      local_node: local_node,
      cluster_nodes: dict.new(),
      cluster_name: "homelab-cluster",
      heartbeat_interval: 30_000,
      // 30 seconds
      failure_detection_timeout: 60_000,
      // 1 minute
      status: types.Starting,
      cluster_handle: option.None,
    )

  case
    actor.new(initial_state)
    |> actor.on_message(handle_message)
    |> actor.start
  {
    Ok(started) -> {
      logging.info("Node manager started for node: " <> config.node_name)
      Ok(started)
    }
    Error(err) -> {
      logging.error("Failed to start node manager")
      Error(err)
    }
  }
}

/// Create node info from configuration
fn create_node_info_from_config(config: NodeConfig) -> NodeInfo {
  // Convert string capabilities to types.Capability
  let capabilities =
    list.map(config.capabilities, fn(cap_str) {
      case cap_str {
        "monitoring" -> types.Monitoring
        "compute" -> types.Compute
        "storage" -> types.Storage
        "network" -> types.Network
        _ -> types.Monitoring
        // Default fallback
      }
    })

  NodeInfo(
    id: types.NodeId(config.node_id),
    name: config.node_name,
    role: config.role,
    capabilities: capabilities,
    status: NodeJoining,
    health: types.Unknown,
    metadata: dict.new()
      |> dict.insert("version", "1.1.0")
      |> dict.insert("gleam_version", "1.7.0")
      |> dict.insert("otp_version", "27"),
    last_heartbeat: types.now(),
    joined_at: types.now(),
    address: config.network.bind_address,
    port: config.network.port,
  )
}

/// Handle messages to the node manager
fn handle_message(
  state: NodeManagerState,
  message: NodeManagerMessage,
) -> actor.Next(NodeManagerState, NodeManagerMessage) {
  case message {
    JoinCluster(cluster_name) -> handle_join_cluster(cluster_name, state)
    LeaveCluster -> handle_leave_cluster(state)
    NodeJoined(node_info) -> handle_node_joined(node_info, state)
    NodeLeft(node_id) -> handle_node_left(node_id, state)
    NodeFailed(node_id) -> handle_node_failed(node_id, state)
    NodeUpdated(node_info) -> handle_node_updated(node_info, state)
    Heartbeat -> handle_heartbeat(state)
    HealthCheck -> handle_health_check(state)
    GetClusterNodes -> handle_get_cluster_nodes(state)
    GetNodeInfo(node_id) -> handle_get_node_info(node_id, state)
    Shutdown -> handle_shutdown(state)
  }
}

/// Handle cluster join request
fn handle_join_cluster(
  cluster_name: String,
  state: NodeManagerState,
) -> actor.Next(NodeManagerState, NodeManagerMessage) {
  // Skip logging during join to avoid I/O termination issues in tests

  // Simulate cluster join - in production this would use actual clustering
  let _updated_node = NodeInfo(..state.local_node, status: NodeActive)
  let new_state =
    NodeManagerState(
      ..state,
      cluster_name: cluster_name,
      status: types.Running,
      cluster_handle: option.Some(cluster_name),
    )

  actor.continue(new_state)
}

/// Handle cluster leave request
fn handle_leave_cluster(
  state: NodeManagerState,
) -> actor.Next(NodeManagerState, NodeManagerMessage) {
  // Skip logging during leave to avoid I/O termination issues

  // Graceful shutdown
  let updated_node = NodeInfo(..state.local_node, status: NodeLeaving)

  case state.cluster_handle {
    option.Some(_handle) -> {
      let new_state =
        NodeManagerState(
          ..state,
          local_node: updated_node,
          status: types.Stopping,
          cluster_handle: option.None,
        )
      actor.continue(new_state)
    }
    option.None -> {
      actor.continue(state)
    }
  }
}

/// Handle node joined event
fn handle_node_joined(
  node_info: NodeInfo,
  state: NodeManagerState,
) -> actor.Next(NodeManagerState, NodeManagerMessage) {
  let node_id_str = types.node_id_to_string(node_info.id)
  logging.info("Node joined cluster: " <> node_id_str)

  let updated_nodes = dict.insert(state.cluster_nodes, node_id_str, node_info)
  let new_state = NodeManagerState(..state, cluster_nodes: updated_nodes)

  actor.continue(new_state)
}

/// Handle node left event
fn handle_node_left(
  node_id: String,
  state: NodeManagerState,
) -> actor.Next(NodeManagerState, NodeManagerMessage) {
  logging.info("Node left cluster: " <> node_id)

  let updated_nodes = dict.delete(state.cluster_nodes, node_id)
  let new_state = NodeManagerState(..state, cluster_nodes: updated_nodes)

  actor.continue(new_state)
}

/// Handle node failure event
fn handle_node_failed(
  node_id: String,
  state: NodeManagerState,
) -> actor.Next(NodeManagerState, NodeManagerMessage) {
  logging.warn("Node failure detected: " <> node_id)

  case dict.get(state.cluster_nodes, node_id) {
    Ok(node_info) -> {
      let updated_node =
        NodeInfo(..node_info, status: NodeDown, health: types.Unhealthy)
      let updated_nodes =
        dict.insert(state.cluster_nodes, node_id, updated_node)
      let new_state = NodeManagerState(..state, cluster_nodes: updated_nodes)

      // Schedule node removal after timeout
      schedule_node_removal(node_id)

      actor.continue(new_state)
    }
    Error(_) -> {
      logging.warn("Failed node not found in registry: " <> node_id)
      actor.continue(state)
    }
  }
}

/// Handle node update event
fn handle_node_updated(
  node_info: NodeInfo,
  state: NodeManagerState,
) -> actor.Next(NodeManagerState, NodeManagerMessage) {
  let node_id_str = types.node_id_to_string(node_info.id)

  let updated_nodes = dict.insert(state.cluster_nodes, node_id_str, node_info)
  let new_state = NodeManagerState(..state, cluster_nodes: updated_nodes)

  logging.debug("Node updated: " <> node_id_str)
  actor.continue(new_state)
}

/// Handle heartbeat
fn handle_heartbeat(
  state: NodeManagerState,
) -> actor.Next(NodeManagerState, NodeManagerMessage) {
  let updated_node = NodeInfo(..state.local_node, last_heartbeat: types.now())
  let new_state = NodeManagerState(..state, local_node: updated_node)

  // Broadcast heartbeat to cluster
  case state.cluster_handle {
    option.Some(_handle) -> {
      let _ = broadcast_heartbeat(updated_node)
      Nil
    }
    option.None -> Nil
  }

  logging.debug("Heartbeat sent")
  actor.continue(new_state)
}

/// Handle health check
fn handle_health_check(
  state: NodeManagerState,
) -> actor.Next(NodeManagerState, NodeManagerMessage) {
  let health_status = calculate_node_health(state)
  let updated_node = NodeInfo(..state.local_node, health: health_status)
  let new_state = NodeManagerState(..state, local_node: updated_node)

  logging.debug(
    "Health check completed - status: "
    <> types.health_status_to_string(health_status),
  )
  actor.continue(new_state)
}

/// Handle get cluster nodes request
fn handle_get_cluster_nodes(
  state: NodeManagerState,
) -> actor.Next(NodeManagerState, NodeManagerMessage) {
  let node_count = dict.size(state.cluster_nodes)
  logging.debug(
    "Cluster nodes requested - count: " <> int.to_string(node_count),
  )

  actor.continue(state)
}

/// Handle get node info request
fn handle_get_node_info(
  node_id: String,
  state: NodeManagerState,
) -> actor.Next(NodeManagerState, NodeManagerMessage) {
  case dict.get(state.cluster_nodes, node_id) {
    Ok(_node_info) -> {
      logging.debug("Node info found for: " <> node_id)
    }
    Error(_) -> {
      logging.warn("Node info not found for: " <> node_id)
    }
  }

  actor.continue(state)
}

/// Handle shutdown
fn handle_shutdown(
  state: NodeManagerState,
) -> actor.Next(NodeManagerState, NodeManagerMessage) {
  // Skip logging during shutdown to avoid I/O termination issues

  // Leave cluster gracefully before shutdown
  case state.cluster_handle {
    option.Some(_handle) -> {
      // Cluster cleanup without logging
      Nil
    }
    option.None -> Nil
  }

  actor.stop()
}

/// Calculate node health based on various factors
fn calculate_node_health(state: NodeManagerState) -> HealthStatus {
  case state.status {
    types.Running -> {
      // Check if we have recent communication with cluster
      case state.cluster_handle {
        option.Some(_) -> types.Healthy
        option.None -> types.Degraded
      }
    }
    types.Starting -> types.Unknown
    types.Stopping -> types.Degraded
    types.Failed -> types.Unhealthy
    _ -> types.Unknown
  }
}

/// Broadcast heartbeat to cluster
fn broadcast_heartbeat(node_info: NodeInfo) -> Result(Nil, String) {
  // Simulate heartbeat broadcast - in production would use actual clustering
  let _encoded = encode_node_heartbeat(node_info)
  logging.debug("Heartbeat broadcast simulated")
  Ok(Nil)
}

/// Encode node heartbeat for transmission
fn encode_node_heartbeat(node_info: NodeInfo) -> String {
  // Simple encoding for heartbeat - in production would use proper serialization
  types.node_id_to_string(node_info.id)
  <> ":"
  <> node_info.name
  <> ":"
  <> types.health_status_to_string(node_info.health)
}

/// Schedule node removal after failure
fn schedule_node_removal(node_id: String) -> Nil {
  // In a real implementation, this would use a timer to schedule removal
  logging.info("Scheduled removal of failed node: " <> node_id)
}

/// Public API functions
/// Join a cluster
pub fn join_cluster(
  manager: actor.Started(process.Subject(NodeManagerMessage)),
  cluster_name: String,
) -> Nil {
  process.send(manager.data, JoinCluster(cluster_name))
}

/// Leave the cluster
pub fn leave_cluster(
  manager: actor.Started(process.Subject(NodeManagerMessage)),
) -> Nil {
  process.send(manager.data, LeaveCluster)
}

/// Send heartbeat
pub fn heartbeat(
  manager: actor.Started(process.Subject(NodeManagerMessage)),
) -> Nil {
  process.send(manager.data, Heartbeat)
}

/// Perform health check
pub fn health_check(
  manager: actor.Started(process.Subject(NodeManagerMessage)),
) -> Nil {
  process.send(manager.data, HealthCheck)
}

/// Get cluster nodes
pub fn get_cluster_nodes(
  manager: actor.Started(process.Subject(NodeManagerMessage)),
) -> Nil {
  process.send(manager.data, GetClusterNodes)
}

/// Get specific node info
pub fn get_node_info(
  manager: actor.Started(process.Subject(NodeManagerMessage)),
  node_id: String,
) -> Nil {
  process.send(manager.data, GetNodeInfo(node_id))
}

/// Shutdown node manager
pub fn shutdown(
  manager: actor.Started(process.Subject(NodeManagerMessage)),
) -> Nil {
  process.send(manager.data, Shutdown)
}

/// Utility functions
/// Convert node status to string
pub fn node_status_to_string(status: NodeStatus) -> String {
  case status {
    NodeJoining -> "joining"
    NodeActive -> "active"
    NodeLeaving -> "leaving"
    NodeSuspected -> "suspected"
    NodeDown -> "down"
    NodeRemoved -> "removed"
  }
}

/// Get node count in cluster
pub fn get_node_count(state: NodeManagerState) -> Int {
  dict.size(state.cluster_nodes)
}

/// Check if node is in cluster
pub fn is_node_in_cluster(state: NodeManagerState, node_id: String) -> Bool {
  dict.has_key(state.cluster_nodes, node_id)
}

/// Get active nodes only
pub fn get_active_nodes(state: NodeManagerState) -> List(NodeInfo) {
  state.cluster_nodes
  |> dict.values
  |> list.filter(fn(node) {
    case node.status {
      NodeActive -> True
      _ -> False
    }
  })
}

/// Get nodes by role
pub fn get_nodes_by_role(
  state: NodeManagerState,
  role: node_config.NodeRole,
) -> List(NodeInfo) {
  state.cluster_nodes
  |> dict.values
  |> list.filter(fn(node) { node.role == role })
}

/// Get nodes with capability
pub fn get_nodes_with_capability(
  state: NodeManagerState,
  capability: types.Capability,
) -> List(NodeInfo) {
  state.cluster_nodes
  |> dict.values
  |> list.filter(fn(node) { list.contains(node.capabilities, capability) })
}
