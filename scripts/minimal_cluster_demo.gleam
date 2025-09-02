/// Minimal cluster demonstration for homelab system
/// Simple working demo without complex supervisors
import gleam/dict
import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/otp/actor

import homelab_system/cluster/cluster_manager
import homelab_system/cluster/discovery
import homelab_system/cluster/simple_health_monitor
import homelab_system/config/cluster_config
import homelab_system/config/node_config
import homelab_system/messaging/distributed_pubsub
import homelab_system/utils/types

/// Simple demo node
pub type DemoNode {
  DemoNode(
    node_id: String,
    cluster_manager: process.Subject(cluster_manager.ClusterManagerMessage),
  )
}

/// Main demo entry point
pub fn main() -> Nil {
  io.println("🚀 Starting Minimal Homelab Cluster Demo")
  io.println("========================================")

  case run_minimal_demo() {
    Ok(_) -> io.println("✅ Demo completed successfully!")
    Error(reason) -> io.println("❌ Demo failed: " <> reason)
  }
}

/// Run a simple demo
fn run_minimal_demo() -> Result(Nil, String) {
  io.println("📋 Starting minimal cluster demo...")

  // Create a simple node configuration
  let config = create_simple_config("demo-node-1")

  // Start cluster manager
  case cluster_manager.start_link(config) {
    Ok(cluster) -> {
      io.println("✅ Cluster manager started!")

      // Demonstrate basic cluster operations
      demonstrate_basic_cluster(cluster.subject)

      // Clean up
      process.sleep(2000)
      let _ = actor.shutdown(cluster.subject)
      Ok(Nil)
    }
    Error(_) -> Error("Failed to start cluster manager")
  }
}

/// Create a simple node configuration
fn create_simple_config(node_id: String) -> node_config.NodeConfig {
  node_config.NodeConfig(
    node_id: node_id,
    node_name: "demo-" <> node_id,
    role: node_config.Coordinator,
    environment: "demo",
    log_level: "info",
    network: node_config.NetworkConfig(
      bind_address: "127.0.0.1",
      port: 8000,
      max_connections: 100,
      connection_timeout: 5000,
    ),
    features: node_config.FeatureConfig(
      clustering: True,
      monitoring: True,
      web_interface: False,
      metrics: True,
      tracing: False,
    ),
    cluster: create_simple_cluster_config(),
    domains: dict.new(),
    metadata: dict.from_list([#("demo", "true")]),
  )
}

/// Create a simple cluster configuration
fn create_simple_cluster_config() -> cluster_config.ClusterConfig {
  cluster_config.ClusterConfig(
    cluster_name: "demo-cluster",
    discovery: cluster_config.DiscoveryConfig(
      method: cluster_config.Static,
      bootstrap_nodes: ["127.0.0.1:8000"],
      heartbeat_interval: 2000,
      failure_threshold: 3,
      cleanup_interval: 10_000,
    ),
    coordination: cluster_config.CoordinationConfig(
      consensus_algorithm: cluster_config.Simple,
      election_timeout: 5000,
      heartbeat_timeout: 2000,
      max_log_entries: 1000,
    ),
    networking: cluster_config.NetworkingConfig(
      compression: False,
      encryption: False,
      buffer_size: 8192,
      max_message_size: 1_048_576,
    ),
    resilience: cluster_config.ResilienceConfig(
      partition_tolerance: True,
      auto_healing: True,
      split_brain_detection: True,
      graceful_shutdown_timeout: 5000,
    ),
  )
}

/// Demonstrate basic cluster functionality
fn demonstrate_basic_cluster(
  cluster: process.Subject(cluster_manager.ClusterManagerMessage),
) -> Nil {
  io.println("🔗 Testing basic cluster operations...")

  // Join cluster
  process.send(cluster, cluster_manager.JoinCluster)
  io.println("✓ Sent join cluster command")

  // Allow some processing time
  process.sleep(1000)

  // Get cluster status
  case cluster_manager.get_cluster_status(cluster) {
    Ok(_status) -> {
      io.println("✓ Retrieved cluster status successfully")
      // In a real demo we'd display the status details
    }
    Error(reason) -> {
      io.println("⚠️  Failed to get cluster status: " <> reason)
    }
  }

  // Test ping functionality
  let node_id = types.NodeId("demo-node-1")
  case cluster_manager.ping_node(cluster, node_id) {
    Ok(response) -> {
      io.println("✓ Ping successful: " <> response)
    }
    Error(reason) -> {
      io.println("⚠️  Ping failed: " <> reason)
    }
  }

  // Broadcast a test event
  let test_event = cluster_manager.NodeJoined(node_id, create_demo_node_info())
  cluster_manager.broadcast_event(cluster, test_event)
  io.println("✓ Broadcasted test event")

  io.println("📊 Basic cluster operations completed!")
}

/// Create demo node info
fn create_demo_node_info() -> cluster_manager.NodeInfo {
  cluster_manager.NodeInfo(
    id: types.NodeId("demo-node-1"),
    name: "demo-node-1",
    role: node_config.Coordinator,
    capabilities: [types.Monitoring, types.WebInterface],
    health: types.Healthy,
    metadata: dict.from_list([#("demo", "true")]),
    address: "127.0.0.1",
    port: 8000,
    joined_at: 0,
    last_seen: 0,
  )
}
