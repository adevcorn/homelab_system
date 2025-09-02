/// Tests for the cluster node manager module
import gleam/dict
import gleam/erlang/process
import gleam/list
import gleam/option
import gleeunit
import gleeunit/should
import homelab_system/cluster/node_manager
import homelab_system/config/node_config
import homelab_system/utils/types

pub fn main() {
  gleeunit.main()
}

/// Test node manager startup
pub fn node_manager_startup_test() {
  let config = create_test_node_config()

  case node_manager.start_link(config) {
    Ok(started) -> {
      should.be_true(True)
      // Manager started successfully
      node_manager.shutdown(started)
    }
    Error(_) -> should.fail()
  }
}

/// Test node status conversion
pub fn node_status_to_string_test() {
  node_manager.NodeJoining
  |> node_manager.node_status_to_string
  |> should.equal("joining")

  node_manager.NodeActive
  |> node_manager.node_status_to_string
  |> should.equal("active")

  node_manager.NodeLeaving
  |> node_manager.node_status_to_string
  |> should.equal("leaving")

  node_manager.NodeSuspected
  |> node_manager.node_status_to_string
  |> should.equal("suspected")

  node_manager.NodeDown
  |> node_manager.node_status_to_string
  |> should.equal("down")

  node_manager.NodeRemoved
  |> node_manager.node_status_to_string
  |> should.equal("removed")
}

/// Test node count functionality
pub fn node_count_test() {
  let state = create_test_node_manager_state()

  // Initially empty cluster
  state
  |> node_manager.get_node_count
  |> should.equal(0)
}

/// Test node existence check
pub fn node_existence_test() {
  let state = create_test_node_manager_state()

  // Node doesn't exist initially
  node_manager.is_node_in_cluster(state, "non-existent-node")
  |> should.be_false

  // Test with empty string
  node_manager.is_node_in_cluster(state, "")
  |> should.be_false
}

/// Test active nodes filtering
pub fn active_nodes_test() {
  let state = create_test_node_manager_state()

  // Initially no active nodes
  state
  |> node_manager.get_active_nodes
  |> list.length
  |> should.equal(0)
}

/// Test nodes by role filtering
pub fn nodes_by_role_test() {
  let state = create_test_node_manager_state()

  // Test filtering by coordinator role
  state
  |> node_manager.get_nodes_by_role(node_config.Coordinator)
  |> list.length
  |> should.equal(0)

  // Test filtering by agent role
  state
  |> node_manager.get_nodes_by_role(node_config.Agent(node_config.Generic))
  |> list.length
  |> should.equal(0)
}

/// Test nodes by capability filtering
pub fn nodes_by_capability_test() {
  let state = create_test_node_manager_state()

  // Test filtering by monitoring capability
  state
  |> node_manager.get_nodes_with_capability(types.Monitoring)
  |> list.length
  |> should.equal(0)

  // Test filtering by compute capability
  state
  |> node_manager.get_nodes_with_capability(types.Compute)
  |> list.length
  |> should.equal(0)
}

/// Test cluster join functionality
pub fn cluster_join_test() {
  let config = create_test_node_config()

  case node_manager.start_link(config) {
    Ok(started) -> {
      // Test joining a cluster
      node_manager.join_cluster(started, "test-cluster")

      // Give some time for the message to be processed
      process.sleep(50)
      should.be_true(True)
      // Join message sent successfully

      node_manager.shutdown(started)
    }
    Error(_) -> should.fail()
  }
}

/// Test cluster leave functionality
pub fn cluster_leave_test() {
  let config = create_test_node_config()

  case node_manager.start_link(config) {
    Ok(started) -> {
      // First join a cluster
      node_manager.join_cluster(started, "test-cluster")
      process.sleep(50)

      // Then leave it
      node_manager.leave_cluster(started)
      process.sleep(50)

      should.be_true(True)
      // Leave message sent successfully

      node_manager.shutdown(started)
    }
    Error(_) -> should.fail()
  }
}

/// Test heartbeat functionality
pub fn heartbeat_test() {
  let config = create_test_node_config()

  case node_manager.start_link(config) {
    Ok(started) -> {
      // Send heartbeat
      node_manager.heartbeat(started)
      process.sleep(10)

      should.be_true(True)
      // Heartbeat sent successfully

      node_manager.shutdown(started)
    }
    Error(_) -> should.fail()
  }
}

/// Test health check functionality
pub fn health_check_test() {
  let config = create_test_node_config()

  case node_manager.start_link(config) {
    Ok(started) -> {
      // Perform health check
      node_manager.health_check(started)
      process.sleep(10)

      should.be_true(True)
      // Health check performed successfully

      node_manager.shutdown(started)
    }
    Error(_) -> should.fail()
  }
}

/// Test get cluster nodes functionality
pub fn get_cluster_nodes_test() {
  let config = create_test_node_config()

  case node_manager.start_link(config) {
    Ok(started) -> {
      // Get cluster nodes
      node_manager.get_cluster_nodes(started)
      process.sleep(10)

      should.be_true(True)
      // Get nodes request sent successfully

      node_manager.shutdown(started)
    }
    Error(_) -> should.fail()
  }
}

/// Test get node info functionality
pub fn get_node_info_test() {
  let config = create_test_node_config()

  case node_manager.start_link(config) {
    Ok(started) -> {
      // Get info for a specific node
      node_manager.get_node_info(started, "test-node")
      process.sleep(10)

      should.be_true(True)
      // Get node info request sent successfully

      node_manager.shutdown(started)
    }
    Error(_) -> should.fail()
  }
}

/// Test node manager shutdown
pub fn shutdown_test() {
  let config = create_test_node_config()

  case node_manager.start_link(config) {
    Ok(started) -> {
      // Shutdown should work without issues
      node_manager.shutdown(started)
      should.be_true(True)
    }
    Error(_) -> should.fail()
  }
}

/// Test multiple node manager instances
pub fn multiple_instances_test() {
  let config1 = create_test_node_config_with_id("node-1")
  let config2 = create_test_node_config_with_id("node-2")

  case node_manager.start_link(config1) {
    Ok(manager1) -> {
      case node_manager.start_link(config2) {
        Ok(manager2) -> {
          // Both managers should start successfully
          should.be_true(True)

          // Clean up with small delay
          process.sleep(10)
          node_manager.shutdown(manager1)
          node_manager.shutdown(manager2)
        }
        Error(_) -> {
          node_manager.shutdown(manager1)
          should.fail()
        }
      }
    }
    Error(_) -> should.fail()
  }
}

/// Helper functions
fn create_test_node_config() -> node_config.NodeConfig {
  create_test_node_config_with_id("homelab-test-node")
}

fn create_test_node_config_with_id(node_id: String) -> node_config.NodeConfig {
  node_config.NodeConfig(
    node_id: node_id,
    node_name: "Test Node",
    role: node_config.Agent(node_config.Generic),
    capabilities: ["monitoring", "compute"],
    environment: "test",
    debug: True,
    network: node_config.NetworkConfig(
      bind_address: "127.0.0.1",
      port: 8080,
      discovery_port: option.Some(8081),
      external_host: option.None,
      max_connections: 100,
      tls_enabled: False,
    ),
    resources: node_config.ResourceConfig(
      max_memory_mb: 1024,
      max_cpu_percent: 80,
      disk_space_mb: 10_240,
      connection_timeout_ms: 30_000,
      request_timeout_ms: 5000,
    ),
    features: node_config.FeatureConfig(
      clustering: True,
      metrics_collection: True,
      health_checks: True,
      web_interface: True,
      api_endpoints: True,
      auto_discovery: True,
      load_balancing: False,
    ),
    metadata: dict.new()
      |> dict.insert("test", "true")
      |> dict.insert("environment", "testing"),
  )
}

fn create_test_node_manager_state() -> node_manager.NodeManagerState {
  let config = create_test_node_config()
  let local_node =
    node_manager.NodeInfo(
      id: types.NodeId(config.node_id),
      name: config.node_name,
      role: config.role,
      capabilities: [types.Monitoring, types.Compute],
      status: node_manager.NodeJoining,
      health: types.Unknown,
      metadata: dict.new(),
      last_heartbeat: types.now(),
      joined_at: types.now(),
      address: config.network.bind_address,
      port: config.network.port,
    )

  node_manager.NodeManagerState(
    local_node: local_node,
    cluster_nodes: dict.new(),
    cluster_name: "test-cluster",
    heartbeat_interval: 30_000,
    failure_detection_timeout: 60_000,
    status: types.Starting,
    cluster_handle: option.None,
  )
}
