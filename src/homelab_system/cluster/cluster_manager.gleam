/// Cluster Manager for Homelab System
///
/// This module provides distributed clustering functionality using the glyn library
/// for node discovery, communication, and management. It handles joining/leaving
/// clusters, node health monitoring, and distributed message passing.
import gleam/dict.{type Dict}

import gleam/dynamic/decode
import gleam/erlang/atom
import gleam/erlang/process.{type Subject}
import gleam/otp/actor

import glyn/pubsub

import homelab_system/config/node_config.{type NodeConfig}
import homelab_system/utils/logging
import homelab_system/utils/types.{
  type HealthStatus, type NodeId, type ServiceStatus, Failed, Healthy, Starting,
}

/// Cluster events that can be published/subscribed to
pub type ClusterEvent {
  NodeJoined(node_id: NodeId, node_info: NodeInfo)
  NodeLeft(node_id: NodeId)
  NodeHealthChanged(node_id: NodeId, health: HealthStatus)
  NodeMetadataUpdated(node_id: NodeId, metadata: Dict(String, String))
  ClusterSizeChanged(size: Int)
}

/// Commands that can be sent to specific nodes via registry
pub type ClusterCommand {
  Ping(reply_with: Subject(String))
  GetNodeInfo(reply_with: Subject(NodeInfo))
  UpdateMetadata(metadata: Dict(String, String))
  RequestShutdown
}

/// Node information for cluster members
pub type NodeInfo {
  NodeInfo(
    id: NodeId,
    name: String,
    role: node_config.NodeRole,
    capabilities: List(String),
    health: HealthStatus,
    metadata: Dict(String, String),
    address: String,
    port: Int,
    joined_at: Int,
    last_seen: Int,
  )
}

/// Cluster manager state
pub type ClusterManagerState {
  ClusterManagerState(
    local_node: NodeInfo,
    cluster_name: String,
    known_nodes: Dict(NodeId, NodeInfo),
    event_pubsub: pubsub.PubSub(ClusterEvent),
    status: ServiceStatus,
    heartbeat_interval: Int,
  )
}

/// Cluster manager actor messages
pub type ClusterManagerMessage {
  // External API
  JoinCluster
  LeaveCluster
  GetClusterNodes(reply_with: Subject(List(NodeInfo)))
  PublishEvent(event: ClusterEvent)

  // Internal messages
  ClusterEventReceived(event: ClusterEvent)
  ClusterCommandReceived(command: ClusterCommand)
  HeartbeatTick
  NodeHealthCheck(node_id: NodeId)
  Shutdown
}

/// Start the cluster manager
pub fn start_link(
  config: NodeConfig,
) -> Result(
  actor.Started(process.Subject(ClusterManagerMessage)),
  actor.StartError,
) {
  let local_node = node_info_from_config(config)
  let cluster_name = "homelab-cluster"

  // Create PubSub for cluster events
  let event_pubsub =
    pubsub.new(
      cluster_name <> "_events",
      cluster_event_decoder(),
      NodeLeft(types.NodeId("decode_error")),
    )

  // Registry functionality disabled for now

  let initial_state =
    ClusterManagerState(
      local_node: local_node,
      cluster_name: cluster_name,
      known_nodes: dict.new(),
      event_pubsub: event_pubsub,
      status: Starting,
      heartbeat_interval: 30_000,
    )

  actor.new(initial_state)
  |> actor.on_message(handle_cluster_message)
  |> actor.start
}

/// Handle cluster manager messages
fn handle_cluster_message(
  state: ClusterManagerState,
  message: ClusterManagerMessage,
) -> actor.Next(ClusterManagerState, ClusterManagerMessage) {
  case message {
    JoinCluster -> handle_join_cluster(state)
    LeaveCluster -> handle_leave_cluster(state)
    GetClusterNodes(reply_with) -> handle_get_cluster_nodes(state, reply_with)
    PublishEvent(event) -> handle_publish_event(state, event)
    ClusterEventReceived(event) -> handle_cluster_event(state, event)
    ClusterCommandReceived(command) -> handle_cluster_command(state, command)
    HeartbeatTick -> handle_heartbeat_tick(state)
    NodeHealthCheck(node_id) -> handle_node_health_check(state, node_id)
    Shutdown -> handle_shutdown(state)
  }
}

/// Join the cluster
fn handle_join_cluster(
  state: ClusterManagerState,
) -> actor.Next(ClusterManagerState, ClusterManagerMessage) {
  logging.info("Joining cluster: " <> state.cluster_name)

  // Announce our presence to the cluster
  let join_event = NodeJoined(state.local_node.id, state.local_node)
  let _ = pubsub.publish(state.event_pubsub, "cluster", join_event)

  let types.NodeId(node_id_string) = state.local_node.id
  logging.info("Successfully joined cluster as: " <> node_id_string)
  actor.continue(state)
}

/// Leave the cluster
fn handle_leave_cluster(
  state: ClusterManagerState,
) -> actor.Next(ClusterManagerState, ClusterManagerMessage) {
  logging.info("Leaving cluster: " <> state.cluster_name)

  // Announce departure
  let leave_event = NodeLeft(state.local_node.id)
  let _ = pubsub.publish(state.event_pubsub, "cluster", leave_event)

  logging.info("Left cluster successfully")
  actor.continue(state)
}

/// Get list of known cluster nodes
fn handle_get_cluster_nodes(
  state: ClusterManagerState,
  reply_with: Subject(List(NodeInfo)),
) -> actor.Next(ClusterManagerState, ClusterManagerMessage) {
  let nodes = dict.values(state.known_nodes)
  process.send(reply_with, nodes)
  actor.continue(state)
}

/// Publish an event to the cluster
fn handle_publish_event(
  state: ClusterManagerState,
  event: ClusterEvent,
) -> actor.Next(ClusterManagerState, ClusterManagerMessage) {
  let _ = pubsub.publish(state.event_pubsub, "cluster", event)
  actor.continue(state)
}

/// Handle received cluster events
fn handle_cluster_event(
  state: ClusterManagerState,
  event: ClusterEvent,
) -> actor.Next(ClusterManagerState, ClusterManagerMessage) {
  case event {
    NodeJoined(node_id, node_info) -> {
      case node_id == state.local_node.id {
        True -> actor.continue(state)
        // Ignore our own join event
        False -> {
          let types.NodeId(node_id_string) = node_id
          logging.info("Node joined cluster: " <> node_id_string)
          let updated_nodes = dict.insert(state.known_nodes, node_id, node_info)
          let size_event = ClusterSizeChanged(dict.size(updated_nodes) + 1)
          let _ = pubsub.publish(state.event_pubsub, "cluster", size_event)

          actor.continue(
            ClusterManagerState(..state, known_nodes: updated_nodes),
          )
        }
      }
    }
    NodeLeft(node_id) -> {
      case node_id == state.local_node.id {
        True -> actor.continue(state)
        // Ignore our own leave event
        False -> {
          let types.NodeId(node_id_string) = node_id
          logging.info("Node left cluster: " <> node_id_string)
          let updated_nodes = dict.delete(state.known_nodes, node_id)
          let size_event = ClusterSizeChanged(dict.size(updated_nodes) + 1)
          let _ = pubsub.publish(state.event_pubsub, "cluster", size_event)

          actor.continue(
            ClusterManagerState(..state, known_nodes: updated_nodes),
          )
        }
      }
    }
    NodeHealthChanged(node_id, health) -> {
      case dict.get(state.known_nodes, node_id) {
        Ok(node_info) -> {
          let updated_node = NodeInfo(..node_info, health: health)
          let updated_nodes =
            dict.insert(state.known_nodes, node_id, updated_node)
          let types.NodeId(node_id_string) = node_id
          logging.info(
            "Node health changed: "
            <> node_id_string
            <> " -> "
            <> health_to_string(health),
          )
          actor.continue(
            ClusterManagerState(..state, known_nodes: updated_nodes),
          )
        }
        Error(_) -> actor.continue(state)
      }
    }
    NodeMetadataUpdated(node_id, metadata) -> {
      case dict.get(state.known_nodes, node_id) {
        Ok(node_info) -> {
          let updated_node = NodeInfo(..node_info, metadata: metadata)
          let updated_nodes =
            dict.insert(state.known_nodes, node_id, updated_node)
          actor.continue(
            ClusterManagerState(..state, known_nodes: updated_nodes),
          )
        }
        Error(_) -> actor.continue(state)
      }
    }
    ClusterSizeChanged(_size) -> {
      // Just log the size change
      actor.continue(state)
    }
  }
}

/// Handle cluster commands
fn handle_cluster_command(
  state: ClusterManagerState,
  command: ClusterCommand,
) -> actor.Next(ClusterManagerState, ClusterManagerMessage) {
  case command {
    Ping(reply_with) -> {
      let types.NodeId(node_id_string) = state.local_node.id
      process.send(reply_with, "pong from " <> node_id_string)
      actor.continue(state)
    }
    GetNodeInfo(reply_with) -> {
      process.send(reply_with, state.local_node)
      actor.continue(state)
    }
    UpdateMetadata(metadata) -> {
      let updated_node = NodeInfo(..state.local_node, metadata: metadata)
      let event = NodeMetadataUpdated(state.local_node.id, metadata)
      let _ = pubsub.publish(state.event_pubsub, "cluster", event)

      actor.continue(ClusterManagerState(..state, local_node: updated_node))
    }
    RequestShutdown -> {
      logging.info("Received shutdown request via cluster command")
      actor.stop()
    }
  }
}

/// Handle heartbeat tick
fn handle_heartbeat_tick(
  state: ClusterManagerState,
) -> actor.Next(ClusterManagerState, ClusterManagerMessage) {
  // Update our last_seen timestamp
  let updated_node =
    NodeInfo(..state.local_node, last_seen: get_current_timestamp())

  // Publish health update
  let health_event =
    NodeHealthChanged(state.local_node.id, state.local_node.health)
  let _ = pubsub.publish(state.event_pubsub, "cluster", health_event)

  actor.continue(ClusterManagerState(..state, local_node: updated_node))
}

/// Handle node health check
fn handle_node_health_check(
  state: ClusterManagerState,
  node_id: NodeId,
) -> actor.Next(ClusterManagerState, ClusterManagerMessage) {
  case dict.get(state.known_nodes, node_id) {
    Ok(node_info) -> {
      // Check if node hasn't been seen recently
      let current_time = get_current_timestamp()
      let time_since_seen = current_time - node_info.last_seen

      case time_since_seen > 120_000 {
        // 2 minutes
        True -> {
          // Mark node as down
          let updated_node = NodeInfo(..node_info, health: Failed)
          let updated_nodes =
            dict.insert(state.known_nodes, node_id, updated_node)
          let health_event = NodeHealthChanged(node_id, Failed)
          let _ = pubsub.publish(state.event_pubsub, "cluster", health_event)

          let types.NodeId(node_id_string) = node_id
          logging.warn(
            "Node marked as down due to missed heartbeats: " <> node_id_string,
          )
          actor.continue(
            ClusterManagerState(..state, known_nodes: updated_nodes),
          )
        }
        False -> actor.continue(state)
      }
    }
    Error(_) -> actor.continue(state)
  }
}

/// Handle shutdown
fn handle_shutdown(
  state: ClusterManagerState,
) -> actor.Next(ClusterManagerState, ClusterManagerMessage) {
  logging.info("Cluster manager shutting down")
  let _ = handle_leave_cluster(state)
  actor.stop()
}

/// Convert node config to node info
fn node_info_from_config(config: NodeConfig) -> NodeInfo {
  NodeInfo(
    id: types.NodeId(config.node_id),
    name: config.node_name,
    role: config.role,
    capabilities: config.capabilities,
    health: Healthy,
    metadata: config.metadata,
    address: config.network.bind_address,
    port: config.network.port,
    joined_at: get_current_timestamp(),
    last_seen: get_current_timestamp(),
  )
}

/// Helper function to get current timestamp
fn get_current_timestamp() -> Int {
  // Placeholder - in production use proper time functions
  0
}

/// Convert health status to string
fn health_to_string(health: HealthStatus) -> String {
  case health {
    Healthy -> "healthy"
    Failed -> "failed"
    _ -> "unknown"
  }
}

/// Cluster event decoder for glyn
fn cluster_event_decoder() -> decode.Decoder(ClusterEvent) {
  decode.one_of(decode_node_joined(), or: [
    decode_node_left(),
    decode_node_health_changed(),
    decode_node_metadata_updated(),
    decode_cluster_size_changed(),
  ])
}

/// Decode NodeJoined event
fn decode_node_joined() -> decode.Decoder(ClusterEvent) {
  use _ <- decode.field(0, expect_atom("node_joined"))
  use node_id <- decode.field(1, decode.string)
  use node_info <- decode.field(2, node_info_decoder())
  decode.success(NodeJoined(types.NodeId(node_id), node_info))
}

/// Decode NodeLeft event
fn decode_node_left() -> decode.Decoder(ClusterEvent) {
  use _ <- decode.field(0, expect_atom("node_left"))
  use node_id <- decode.field(1, decode.string)
  decode.success(NodeLeft(types.NodeId(node_id)))
}

/// Decode NodeHealthChanged event
fn decode_node_health_changed() -> decode.Decoder(ClusterEvent) {
  use _ <- decode.field(0, expect_atom("node_health_changed"))
  use node_id <- decode.field(1, decode.string)
  use health <- decode.field(2, health_status_decoder())
  decode.success(NodeHealthChanged(types.NodeId(node_id), health))
}

/// Decode NodeMetadataUpdated event
fn decode_node_metadata_updated() -> decode.Decoder(ClusterEvent) {
  use _ <- decode.field(0, expect_atom("node_metadata_updated"))
  use node_id <- decode.field(1, decode.string)
  use metadata <- decode.field(2, decode.dict(decode.string, decode.string))
  decode.success(NodeMetadataUpdated(types.NodeId(node_id), metadata))
}

/// Decode ClusterSizeChanged event
fn decode_cluster_size_changed() -> decode.Decoder(ClusterEvent) {
  use _ <- decode.field(0, expect_atom("cluster_size_changed"))
  use size <- decode.field(1, decode.int)
  decode.success(ClusterSizeChanged(size))
}

/// Helper function to match specific atoms
fn expect_atom(expected: String) -> decode.Decoder(atom.Atom) {
  use value <- decode.then(atom.decoder())
  case atom.to_string(value) == expected {
    True -> decode.success(value)
    False -> decode.failure(value, "Expected atom: " <> expected)
  }
}

/// Node info decoder (simplified)
fn node_info_decoder() -> decode.Decoder(NodeInfo) {
  use id <- decode.field(0, decode.string)
  use name <- decode.field(1, decode.string)
  decode.success(NodeInfo(
    id: types.NodeId(id),
    name: name,
    role: node_config.Agent(node_config.Generic),
    // Simplified
    capabilities: [],
    health: Healthy,
    metadata: dict.new(),
    address: "127.0.0.1",
    port: 4000,
    joined_at: 0,
    last_seen: 0,
  ))
}

/// Health status decoder (simplified)
fn health_status_decoder() -> decode.Decoder(HealthStatus) {
  decode.string
  |> decode.then(fn(status_str) {
    case status_str {
      "healthy" -> decode.success(Healthy)
      "failed" -> decode.success(Failed)
      "down" -> decode.success(Failed)
      _ -> decode.success(Healthy)
    }
  })
}

/// Get cluster status for monitoring
pub fn get_cluster_status(
  subject: Subject(ClusterManagerMessage),
) -> Result(List(NodeInfo), Nil) {
  let reply_subject = process.new_subject()
  process.send(subject, GetClusterNodes(reply_subject))

  case process.receive(reply_subject, 5000) {
    Ok(nodes) -> Ok(nodes)
    Error(_) -> Error(Nil)
  }
}

/// Send a ping to a specific node
/// Ping a specific node (simplified implementation)
pub fn ping_node(
  _cluster_subject: Subject(ClusterManagerMessage),
  node_id: NodeId,
) -> Result(String, String) {
  // Simplified ping - would normally use registry
  let types.NodeId(node_id_string) = node_id
  Ok("pong from " <> node_id_string)
}

/// Broadcast an event to all cluster nodes
pub fn broadcast_event(
  event_pubsub: pubsub.PubSub(ClusterEvent),
  event: ClusterEvent,
) -> Result(Int, Nil) {
  case pubsub.publish(event_pubsub, "cluster", event) {
    Ok(subscriber_count) -> Ok(subscriber_count)
    Error(_) -> Error(Nil)
  }
}
