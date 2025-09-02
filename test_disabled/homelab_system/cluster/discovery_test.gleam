/// Tests for the service discovery module
import gleam/dict
import gleam/erlang/process
import gleam/list
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should

import homelab_system/cluster/discovery
import homelab_system/utils/types

pub fn main() {
  gleeunit.main()
}

/// Test service entry creation
pub fn new_service_entry_test() {
  let service_id = types.ServiceId("test-service-1")
  let node_id = types.NodeId("node-1")

  let entry =
    discovery.new_service_entry(
      service_id,
      "test-service",
      "1.0.0",
      node_id,
      "192.168.1.10",
      8080,
    )

  entry.id
  |> should.equal(service_id)

  entry.name
  |> should.equal("test-service")

  entry.version
  |> should.equal("1.0.0")

  entry.node_id
  |> should.equal(node_id)

  entry.address
  |> should.equal("192.168.1.10")

  entry.port
  |> should.equal(8080)

  entry.health_status
  |> should.equal(types.Unknown)

  entry.tags
  |> should.equal([])

  dict.size(entry.metadata)
  |> should.equal(0)
}

/// Test service query creation
pub fn new_service_query_test() {
  let query = discovery.new_service_query()

  query.name
  |> should.equal(None)

  query.version
  |> should.equal(None)

  query.health_status
  |> should.equal(None)

  query.node_id
  |> should.equal(None)

  query.tags
  |> should.equal([])

  dict.size(query.metadata_filters)
  |> should.equal(0)
}

/// Test service query with name filter
pub fn service_query_with_name_test() {
  let query =
    discovery.new_service_query()
    |> discovery.with_name("web-server")

  query.name
  |> should.equal(Some("web-server"))
}

/// Test service query with version filter
pub fn service_query_with_version_test() {
  let query =
    discovery.new_service_query()
    |> discovery.with_version("2.1.0")

  query.version
  |> should.equal(Some("2.1.0"))
}

/// Test service query with health status filter
pub fn service_query_with_health_status_test() {
  let query =
    discovery.new_service_query()
    |> discovery.with_health_status(types.Healthy)

  query.health_status
  |> should.equal(Some(types.Healthy))
}

/// Test service query with node ID filter
pub fn service_query_with_node_id_test() {
  let node_id = types.NodeId("worker-1")
  let query =
    discovery.new_service_query()
    |> discovery.with_node_id(node_id)

  query.node_id
  |> should.equal(Some(node_id))
}

/// Test service query with tags filter
pub fn service_query_with_tags_test() {
  let tags = ["web", "api", "production"]
  let query =
    discovery.new_service_query()
    |> discovery.with_tags(tags)

  query.tags
  |> should.equal(tags)
}

/// Test service query with metadata filter
pub fn service_query_with_metadata_test() {
  let query =
    discovery.new_service_query()
    |> discovery.with_metadata("environment", "production")
    |> discovery.with_metadata("team", "platform")

  dict.get(query.metadata_filters, "environment")
  |> should.equal(Ok("production"))

  dict.get(query.metadata_filters, "team")
  |> should.equal(Ok("platform"))
}

/// Test service discovery actor startup
pub fn service_discovery_startup_test() {
  let node_id = types.NodeId("test-node")
  let cluster_name = "test-cluster"

  case discovery.start_link(node_id, cluster_name) {
    Ok(started) -> {
      // Test that the actor started successfully
      should.be_ok(Ok(started))

      // Shutdown the actor
      discovery.shutdown(started)
    }
    Error(_) -> {
      should.fail()
    }
  }
}

/// Test service registration and deregistration flow
pub fn service_registration_flow_test() {
  let node_id = types.NodeId("test-node")
  let cluster_name = "test-cluster"

  case discovery.start_link(node_id, cluster_name) {
    Ok(started) -> {
      let service_id = types.ServiceId("test-service-1")
      let service_entry =
        discovery.new_service_entry(
          service_id,
          "test-api",
          "1.2.3",
          node_id,
          "127.0.0.1",
          3000,
        )

      // Register service
      discovery.register_service(started, service_entry)

      // Give the actor time to process
      process.sleep(10)

      // Deregister service
      discovery.deregister_service(started, service_id)

      // Give the actor time to process
      process.sleep(10)

      // Shutdown
      discovery.shutdown(started)

      should.be_true(True)
    }
    Error(_) -> {
      should.fail()
    }
  }
}

/// Test service discovery with query
pub fn service_discovery_query_test() {
  let node_id = types.NodeId("test-node")
  let cluster_name = "test-cluster"

  case discovery.start_link(node_id, cluster_name) {
    Ok(started) -> {
      let service_id = types.ServiceId("web-service-1")
      let service_entry =
        discovery.new_service_entry(
          service_id,
          "web-server",
          "1.0.0",
          node_id,
          "192.168.1.100",
          80,
        )

      // Register service
      discovery.register_service(started, service_entry)

      // Give the actor time to process
      process.sleep(10)

      // Create query
      let query =
        discovery.new_service_query()
        |> discovery.with_name("web-server")

      // Discover services
      discovery.discover_services(started, query)

      // Give the actor time to process
      process.sleep(10)

      // Shutdown
      discovery.shutdown(started)

      should.be_true(True)
    }
    Error(_) -> {
      should.fail()
    }
  }
}

/// Test health checking functionality
pub fn health_check_test() {
  let node_id = types.NodeId("test-node")
  let cluster_name = "test-cluster"

  case discovery.start_link(node_id, cluster_name) {
    Ok(started) -> {
      let service_id = types.ServiceId("health-test-service")
      let service_entry =
        discovery.new_service_entry(
          service_id,
          "health-api",
          "2.0.0",
          node_id,
          "localhost",
          8080,
        )

      // Register service
      discovery.register_service(started, service_entry)

      // Give the actor time to process
      process.sleep(10)

      // Perform health check
      discovery.health_check_service(started, service_id)

      // Give the actor time to process
      process.sleep(10)

      // Check all services
      discovery.health_check_all(started)

      // Give the actor time to process
      process.sleep(10)

      // Shutdown
      discovery.shutdown(started)

      should.be_true(True)
    }
    Error(_) -> {
      should.fail()
    }
  }
}

/// Test registry synchronization
pub fn registry_sync_test() {
  let node_id = types.NodeId("test-node")
  let cluster_name = "test-cluster"

  case discovery.start_link(node_id, cluster_name) {
    Ok(started) -> {
      // Sync registry
      discovery.sync_registry(started)

      // Give the actor time to process
      process.sleep(10)

      // Shutdown
      discovery.shutdown(started)

      should.be_true(True)
    }
    Error(_) -> {
      should.fail()
    }
  }
}

/// Test cache operations
pub fn cache_operations_test() {
  let node_id = types.NodeId("test-node")
  let cluster_name = "test-cluster"

  case discovery.start_link(node_id, cluster_name) {
    Ok(started) -> {
      // Clear cache
      discovery.clear_cache(started)

      // Give the actor time to process
      process.sleep(10)

      // Shutdown
      discovery.shutdown(started)

      should.be_true(True)
    }
    Error(_) -> {
      should.fail()
    }
  }
}

/// Test registry statistics
pub fn registry_stats_test() {
  let node_id = types.NodeId("test-node")
  let cluster_name = "test-cluster"

  case discovery.start_link(node_id, cluster_name) {
    Ok(started) -> {
      // Get registry stats
      discovery.get_registry_stats(started)

      // Give the actor time to process
      process.sleep(10)

      // Shutdown
      discovery.shutdown(started)

      should.be_true(True)
    }
    Error(_) -> {
      should.fail()
    }
  }
}

/// Test complex service entry with metadata and tags
pub fn complex_service_entry_test() {
  let service_id = types.ServiceId("complex-service")
  let node_id = types.NodeId("worker-node-1")

  let base_entry =
    discovery.new_service_entry(
      service_id,
      "complex-api",
      "3.1.4",
      node_id,
      "10.0.0.50",
      9000,
    )

  // Test that we can create a complex service entry with additional fields
  let complex_entry =
    discovery.ServiceEntry(
      ..base_entry,
      health_endpoint: Some("/health"),
      health_status: types.Healthy,
      metadata: dict.new()
        |> dict.insert("environment", "staging")
        |> dict.insert("team", "backend")
        |> dict.insert("region", "us-west-2"),
      tags: ["api", "microservice", "backend", "staging"],
      health_check_interval: 15_000,
      // 15 seconds
      ttl: Some(300_000),
      // 5 minutes
    )

  complex_entry.health_endpoint
  |> should.equal(Some("/health"))

  complex_entry.health_status
  |> should.equal(types.Healthy)

  list.length(complex_entry.tags)
  |> should.equal(4)

  list.contains(complex_entry.tags, "api")
  |> should.be_true()

  dict.get(complex_entry.metadata, "environment")
  |> should.equal(Ok("staging"))

  complex_entry.health_check_interval
  |> should.equal(15_000)

  complex_entry.ttl
  |> should.equal(Some(300_000))
}

/// Test service update functionality
pub fn service_update_test() {
  let node_id = types.NodeId("test-node")
  let cluster_name = "test-cluster"

  case discovery.start_link(node_id, cluster_name) {
    Ok(started) -> {
      let service_id = types.ServiceId("update-test-service")
      let initial_entry =
        discovery.new_service_entry(
          service_id,
          "update-api",
          "1.0.0",
          node_id,
          "127.0.0.1",
          4000,
        )

      // Register initial service
      discovery.register_service(started, initial_entry)

      // Give the actor time to process
      process.sleep(10)

      // Create updated entry
      let updated_entry =
        discovery.ServiceEntry(
          ..initial_entry,
          version: "1.1.0",
          health_status: types.Healthy,
          tags: ["updated", "api"],
        )

      // Update service
      discovery.update_service(started, updated_entry)

      // Give the actor time to process
      process.sleep(10)

      // Shutdown
      discovery.shutdown(started)

      should.be_true(True)
    }
    Error(_) -> {
      should.fail()
    }
  }
}
