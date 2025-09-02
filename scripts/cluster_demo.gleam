/// Cluster demonstration script for homelab system
/// Shows clustering functionality including node discovery, health monitoring, and messaging
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/io
import gleam/list
import gleam/option.{None, Some}
import gleam/otp/actor
import gleam/result
import gleam/string

import homelab_system/cluster/cluster_manager
import homelab_system/cluster/discovery
import homelab_system/cluster/simple_health_monitor
import homelab_system/config/cluster_config
import homelab_system/config/node_config
import homelab_system/messaging/distributed_pubsub
import homelab_system/utils/logging
import homelab_system/utils/types

/// Demo configuration
pub type DemoConfig {
  DemoConfig(
    num_coordinator_nodes: Int,
    num_agent_nodes: Int,
    num_gateway_nodes: Int,
    demo_duration_ms: Int,
    show_verbose_output: Bool,
  )
}

/// Demo node information
pub type DemoNode {
  DemoNode(
    node_id: String,
    node_type: String,
    cluster_manager: process.Subject(cluster_manager.ClusterManagerMessage),
    discovery_service: process.Subject(discovery.ServiceDiscoveryMessage),
    health_monitor: process.Subject(simple_health_monitor.SimpleHealthMessage),
    pubsub: process.Subject(distributed_pubsub.PubSubMessage),
  )
}

/// Main demo entry point
pub fn main() -> Nil {
  io.println("🚀 Starting Homelab System Cluster Demo")
  io.println("========================================")

  let demo_config =
    DemoConfig(
      num_coordinator_nodes: 1,
      num_agent_nodes: 2,
      num_gateway_nodes: 1,
      demo_duration_ms: 30_000,
      // 30 seconds
      show_verbose_output: True,
    )

  case run_cluster_demo(demo_config) {
    Ok(_) -> {
      io.println("✅ Cluster demo completed successfully!")
    }
    Error(reason) -> {
      io.println("❌ Cluster demo failed: " <> reason)
    }
  }
}

/// Run the complete cluster demo
pub fn run_cluster_demo(config: DemoConfig) -> Result(Nil, String) {
  io.println("📋 Demo Configuration:")
  io.println(
    "  Coordinator nodes: " <> int.to_string(config.num_coordinator_nodes),
  )
  io.println("  Agent nodes: " <> int.to_string(config.num_agent_nodes))
  io.println("  Gateway nodes: " <> int.to_string(config.num_gateway_nodes))
  io.println(
    "  Duration: "
    <> int.to_string(config.demo_duration_ms / 1000)
    <> " seconds",
  )
  io.println("")

  // Phase 1: Start cluster nodes
  case start_cluster_nodes(config) {
    Ok(nodes) -> {
      io.println("✅ All cluster nodes started successfully!")

      // Phase 2: Demonstrate cluster formation
      case demonstrate_cluster_formation(nodes, config) {
        Ok(_) -> {
          // Phase 3: Demonstrate service discovery
          case demonstrate_service_discovery(nodes, config) {
            Ok(_) -> {
              // Phase 4: Demonstrate health monitoring
              case demonstrate_health_monitoring(nodes, config) {
                Ok(_) -> {
                  // Phase 5: Demonstrate messaging
                  case demonstrate_messaging(nodes, config) {
                    Ok(_) -> {
                      // Phase 6: Demonstrate failure scenarios
                      case demonstrate_failure_scenarios(nodes, config) {
                        Ok(_) -> {
                          // Cleanup
                          cleanup_demo_nodes(nodes)
                          Ok(Nil)
                        }
                        Error(reason) -> Error("Failure demo error: " <> reason)
                      }
                    }
                    Error(reason) -> Error("Messaging demo error: " <> reason)
                  }
                }
                Error(reason) ->
                  Error("Health monitoring demo error: " <> reason)
              }
            }
            Error(reason) -> Error("Service discovery demo error: " <> reason)
          }
        }
        Error(reason) -> Error("Cluster formation demo error: " <> reason)
      }
    }
    Error(reason) -> Error("Node startup error: " <> reason)
  }
}

/// Start all cluster nodes
fn start_cluster_nodes(config: DemoConfig) -> Result(List(DemoNode), String) {
  io.println("🔧 Starting cluster nodes...")

  // Start coordinator nodes
  case start_coordinator_nodes(config.num_coordinator_nodes) {
    Ok(coordinator_nodes) -> {
      // Start agent nodes
      case start_agent_nodes(config.num_agent_nodes) {
        Ok(agent_nodes) -> {
          // Start gateway nodes
          case start_gateway_nodes(config.num_gateway_nodes) {
            Ok(gateway_nodes) -> {
              let nodes =
                list.append(
                  list.append(coordinator_nodes, agent_nodes),
                  gateway_nodes,
                )
              Ok(nodes)
            }
            Error(reason) -> Error("Failed to start gateway nodes: " <> reason)
          }
        }
        Error(reason) -> Error("Failed to start agent nodes: " <> reason)
      }
    }
    Error(reason) -> Error("Failed to start coordinator nodes: " <> reason)
  }
}

/// Start coordinator nodes
fn start_coordinator_nodes(count: Int) -> Result(List(DemoNode), String) {
  io.println(
    "  🎯 Starting " <> int.to_string(count) <> " coordinator node(s)...",
  )

  list.range(1, count)
  |> list.try_map(fn(i) {
    start_single_node("coordinator-" <> int.to_string(i), "coordinator")
  })
}

/// Start agent nodes
fn start_agent_nodes(count: Int) -> Result(List(DemoNode), String) {
  io.println("  🤖 Starting " <> int.to_string(count) <> " agent node(s)...")

  list.range(1, count)
  |> list.try_map(fn(i) {
    start_single_node("agent-" <> int.to_string(i), "agent")
  })
}

/// Start gateway nodes
fn start_gateway_nodes(count: Int) -> Result(List(DemoNode), String) {
  io.println("  🚪 Starting " <> int.to_string(count) <> " gateway node(s)...")

  list.range(1, count)
  |> list.try_map(fn(i) {
    start_single_node("gateway-" <> int.to_string(i), "gateway")
  })
}

/// Start a single demo node
fn start_single_node(
  node_id: String,
  node_type: String,
) -> Result(DemoNode, String) {
  let node_config = create_demo_node_config(node_id, node_type)
  let cluster_config = create_demo_cluster_config()

  // Start cluster manager
  case cluster_manager.start_link(node_config) {
    Ok(cluster_mgr) -> {
      // Start discovery service
      case discovery.start_link(node_id, "demo-cluster") {
        Ok(discovery_svc) -> {
          // Start health monitor
          case simple_health_monitor.start_link(node_config, cluster_config) {
            Ok(health_mon) -> {
              // Start distributed pubsub
              case distributed_pubsub.start_link("demo-cluster") {
                Ok(pubsub) -> {
                  let demo_node =
                    DemoNode(
                      node_id: node_id,
                      node_type: node_type,
                      cluster_manager: cluster_mgr.subject,
                      discovery_service: discovery_svc.subject,
                      health_monitor: health_mon.subject,
                      pubsub: pubsub.subject,
                    )

                  io.println("    ✓ Started node: " <> node_id)
                  Ok(demo_node)
                }
                Error(_) -> Error("Failed to start pubsub for " <> node_id)
              }
            }
            Error(_) -> Error("Failed to start health monitor for " <> node_id)
          }
        }
        Error(_) -> Error("Failed to start discovery service for " <> node_id)
      }
    }
    Error(_) -> Error("Failed to start cluster manager for " <> node_id)
  }
}

/// Demonstrate cluster formation
fn demonstrate_cluster_formation(
  nodes: List(DemoNode),
  config: DemoConfig,
) -> Result(Nil, String) {
  io.println("")
  io.println("🔗 Demonstrating Cluster Formation")
  io.println("==================================")

  // Allow nodes to discover each other
  io.println("⏳ Allowing cluster formation (5 seconds)...")
  process.sleep(5000)

  // Check cluster status from coordinator
  case find_coordinator_node(nodes) {
    Some(coordinator) -> {
      case cluster_manager.get_cluster_status(coordinator.cluster_manager) {
        Ok(status) -> {
          let node_count = dict.size(status.known_nodes)
          io.println("📊 Cluster Status:")
          io.println("  Total nodes discovered: " <> int.to_string(node_count))
          io.println("  Cluster name: " <> status.cluster_name)
          io.println("  Local node: " <> status.local_node.name)

          case config.show_verbose_output {
            True -> {
              io.println("  Known nodes:")
              status.known_nodes
              |> dict.to_list
              |> list.each(fn(entry) {
                io.println(
                  "    - " <> entry.0 <> " (" <> { entry.1 }.name <> ")",
                )
              })
            }
            False -> Nil
          }

          Ok(Nil)
        }
        Error(reason) -> Error("Failed to get cluster status: " <> reason)
      }
    }
    None -> Error("No coordinator node found")
  }
}

/// Demonstrate service discovery
fn demonstrate_service_discovery(
  nodes: List(DemoNode),
  config: DemoConfig,
) -> Result(Nil, String) {
  io.println("")
  io.println("🔍 Demonstrating Service Discovery")
  io.println("=================================")

  // Register services on different nodes
  case register_demo_services(nodes) {
    Ok(_) -> {
      io.println("✓ Demo services registered")

      // Discover services
      case discover_demo_services(nodes) {
        Ok(discovered_services) -> {
          io.println("📋 Discovered Services:")
          io.println(
            "  Total services found: "
            <> int.to_string(list.length(discovered_services)),
          )

          case config.show_verbose_output {
            True -> {
              discovered_services
              |> list.each(fn(service) {
                io.println(
                  "    - "
                  <> service.name
                  <> " v"
                  <> service.version
                  <> " on "
                  <> service.node_id,
                )
              })
            }
            False -> Nil
          }

          Ok(Nil)
        }
        Error(reason) -> Error("Service discovery failed: " <> reason)
      }
    }
    Error(reason) -> Error("Service registration failed: " <> reason)
  }
}

/// Demonstrate health monitoring
fn demonstrate_health_monitoring(
  nodes: List(DemoNode),
  config: DemoConfig,
) -> Result(Nil, String) {
  io.println("")
  io.println("🏥 Demonstrating Health Monitoring")
  io.println("=================================")

  // Start health checks on all nodes
  nodes
  |> list.each(fn(node) {
    let _ = simple_health_monitor.start_health_checks(node.health_monitor)
    Nil
  })

  io.println("✓ Health monitoring started on all nodes")

  // Wait for health checks to run
  process.sleep(3000)

  // Get health summary from coordinator
  case find_coordinator_node(nodes) {
    Some(coordinator) -> {
      case
        simple_health_monitor.get_health_summary(coordinator.health_monitor)
      {
        Ok(summary) -> {
          io.println("📊 Cluster Health Summary:")
          io.println(
            "  Overall status: "
            <> health_status_to_string(summary.overall_status),
          )
          io.println(
            "  Healthy nodes: "
            <> int.to_string(summary.healthy_nodes)
            <> "/"
            <> int.to_string(summary.total_nodes),
          )
          io.println(
            "  Healthy services: "
            <> int.to_string(summary.healthy_services)
            <> "/"
            <> int.to_string(summary.total_services),
          )

          case list.length(summary.issues) {
            0 -> io.println("  No health issues detected ✅")
            issue_count -> {
              io.println("  Health issues: " <> int.to_string(issue_count))
              case config.show_verbose_output {
                True -> {
                  summary.issues
                  |> list.each(fn(issue) {
                    io.println(
                      "    ⚠️  " <> issue.component <> ": " <> issue.description,
                    )
                  })
                }
                False -> Nil
              }
            }
          }

          Ok(Nil)
        }
        Error(reason) -> Error("Failed to get health summary: " <> reason)
      }
    }
    None -> Error("No coordinator node found")
  }
}

/// Demonstrate messaging
fn demonstrate_messaging(
  nodes: List(DemoNode),
  config: DemoConfig,
) -> Result(Nil, String) {
  io.println("")
  io.println("📨 Demonstrating Distributed Messaging")
  io.println("======================================")

  let test_topic = "demo.cluster.events"

  // Subscribe nodes to demo topic
  nodes
  |> list.each(fn(node) {
    let subscription =
      distributed_pubsub.new_subscription(
        id: "demo-sub-" <> node.node_id,
        node_id: node.node_id,
        pattern: distributed_pubsub.Exact(test_topic),
        handler: fn(_message) { Nil },
        // Placeholder handler
        delivery_guarantee: distributed_pubsub.AtLeastOnce,
        created_at: 0,
      )
    let _ = distributed_pubsub.subscribe(node.pubsub, subscription)
    Nil
  })

  io.println("✓ All nodes subscribed to topic: " <> test_topic)

  // Publish messages from coordinator
  case find_coordinator_node(nodes) {
    Some(coordinator) -> {
      let messages = [
        "Hello from cluster coordinator!",
        "Cluster is fully operational",
        "Demo message broadcast test",
      ]

      messages
      |> list.each(fn(message) {
        let envelope =
          distributed_pubsub.new_message_envelope(
            id: "demo-msg-" <> int.to_string(get_timestamp()),
            topic: test_topic,
            payload: message,
            sender_id: coordinator.node_id,
            timestamp: get_timestamp(),
            priority: distributed_pubsub.Medium,
            delivery_guarantee: distributed_pubsub.AtLeastOnce,
            ttl: Some(60_000),
            // 1 minute
            correlation_id: None,
            headers: dict.new(),
          )

        let _ = distributed_pubsub.publish(coordinator.pubsub, envelope)
        process.sleep(500)
        // Brief pause between messages
      })

      io.println(
        "✓ Published " <> int.to_string(list.length(messages)) <> " messages",
      )

      // Allow message processing
      process.sleep(2000)

      Ok(Nil)
    }
    None -> Error("No coordinator node found")
  }
}

/// Demonstrate failure scenarios
fn demonstrate_failure_scenarios(
  nodes: List(DemoNode),
  config: DemoConfig,
) -> Result(Nil, String) {
  io.println("")
  io.println("⚠️  Demonstrating Failure Scenarios")
  io.println("===================================")

  // Find an agent node to simulate failure
  case find_agent_node(nodes) {
    Some(agent_node) -> {
      io.println("🔥 Simulating node failure for: " <> agent_node.node_id)

      // Shutdown the agent node's services
      let _ = actor.shutdown(agent_node.cluster_manager)
      let _ = actor.shutdown(agent_node.health_monitor)

      io.println("✓ Node " <> agent_node.node_id <> " shut down")

      // Wait for failure detection
      io.println("⏳ Waiting for failure detection (5 seconds)...")
      process.sleep(5000)

      // Check cluster status after failure
      case find_coordinator_node(nodes) {
        Some(coordinator) -> {
          case
            simple_health_monitor.get_health_summary(coordinator.health_monitor)
          {
            Ok(summary) -> {
              io.println("📊 Post-failure Cluster Status:")
              io.println(
                "  Overall status: "
                <> health_status_to_string(summary.overall_status),
              )
              io.println(
                "  Healthy nodes: "
                <> int.to_string(summary.healthy_nodes)
                <> "/"
                <> int.to_string(summary.total_nodes),
              )

              case list.length(summary.issues) {
                0 -> io.println("  No issues detected (unexpected)")
                issue_count -> {
                  io.println(
                    "  Detected issues: " <> int.to_string(issue_count),
                  )
                  summary.issues
                  |> list.take(3)
                  // Show first 3 issues
                  |> list.each(fn(issue) {
                    io.println(
                      "    🚨 " <> issue.component <> ": " <> issue.description,
                    )
                  })
                }
              }

              Ok(Nil)
            }
            Error(reason) ->
              Error("Failed to get post-failure health summary: " <> reason)
          }
        }
        None -> Error("No coordinator node found")
      }
    }
    None -> {
      io.println("ℹ️  No agent nodes available for failure simulation")
      Ok(Nil)
    }
  }
}

// Helper functions

fn create_demo_node_config(
  node_id: String,
  node_type: String,
) -> node_config.NodeConfig {
  let role = case node_type {
    "coordinator" -> node_config.Coordinator
    "gateway" -> node_config.Gateway
    "agent" -> node_config.Agent(node_config.Generic)
    _ -> node_config.Agent(node_config.Generic)
  }

  node_config.NodeConfig(
    node_id: node_id,
    node_name: "demo-" <> node_id,
    role: role,
    environment: "demo",
    log_level: "info",
    network: node_config.NetworkConfig(
      bind_address: "127.0.0.1",
      port: 8000 + hash_string(node_id),
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
    cluster: create_demo_cluster_config(),
    domains: dict.new(),
    metadata: dict.from_list([
      #("demo", "true"),
      #("type", node_type),
    ]),
  )
}

fn create_demo_cluster_config() -> cluster_config.ClusterConfig {
  cluster_config.ClusterConfig(
    name: "demo-cluster",
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

fn find_coordinator_node(nodes: List(DemoNode)) -> option.Option(DemoNode) {
  list.find(nodes, fn(node) { node.node_type == "coordinator" })
}

fn find_agent_node(nodes: List(DemoNode)) -> option.Option(DemoNode) {
  list.find(nodes, fn(node) { node.node_type == "agent" })
}

fn register_demo_services(nodes: List(DemoNode)) -> Result(Nil, String) {
  // Register different services on different nodes
  nodes
  |> list.index_map(fn(node, index) {
    let service_name = case node.node_type {
      "coordinator" -> "cluster-coordinator"
      "agent" -> "monitoring-agent"
      "gateway" -> "api-gateway"
      _ -> "generic-service"
    }

    let service_entry =
      discovery.new_service_entry(
        id: service_name <> "-" <> int.to_string(index),
        name: service_name,
        version: "1.0.0",
        node_id: node.node_id,
        address: "127.0.0.1",
        port: 9000 + index,
        health_endpoint: "/health",
        metadata: dict.from_list([
          #("environment", "demo"),
          #("node_type", node.node_type),
        ]),
        tags: [node.node_type, "demo"],
      )

    discovery.register_service(node.discovery_service, service_entry)
  })
  |> list.all(result.is_ok)
  |> fn(success) {
    case success {
      True -> Ok(Nil)
      False -> Error("Some service registrations failed")
    }
  }
}

fn discover_demo_services(
  nodes: List(DemoNode),
) -> Result(List(discovery.ServiceEntry), String) {
  case find_coordinator_node(nodes) {
    Some(coordinator) -> {
      let query = discovery.new_service_query()
      discovery.discover_services(coordinator.discovery_service, query)
    }
    None -> Error("No coordinator node available for service discovery")
  }
}

fn cleanup_demo_nodes(nodes: List(DemoNode)) -> Nil {
  io.println("")
  io.println("🧹 Cleaning up demo nodes...")

  nodes
  |> list.each(fn(node) {
    let _ = actor.shutdown(node.cluster_manager)
    let _ = actor.shutdown(node.discovery_service)
    let _ = actor.shutdown(node.health_monitor)
    let _ = actor.shutdown(node.pubsub)
    Nil
  })

  io.println("✓ All demo nodes cleaned up")
}

fn health_status_to_string(status: types.HealthStatus) -> String {
  case status {
    types.Healthy -> "Healthy ✅"
    types.Degraded -> "Degraded ⚠️"
    types.Failed -> "Failed ❌"
    types.NodeDown -> "Down 🔴"
  }
}

fn hash_string(s: String) -> Int {
  // Simple hash function for demo ports
  string.length(s) * 7 % 1000
}

fn get_timestamp() -> Int {
  // Placeholder timestamp
  1_000_000
}
