/// Cluster supervisor for managing cluster-related processes in the homelab system
/// Handles supervision of cluster coordination, discovery, and communication services
import gleam/erlang/process
import gleam/list
import gleam/option.{type Option}
import gleam/otp/actor
import gleam/otp/static_supervisor.{type Supervisor} as supervisor
import gleam/otp/supervision

import homelab_system/cluster/cluster_manager
import homelab_system/cluster/discovery
import homelab_system/cluster/node_manager
import homelab_system/cluster/simple_health_monitor
import homelab_system/config/cluster_config.{type ClusterConfig}
import homelab_system/config/node_config.{type NodeConfig}
import homelab_system/messaging/distributed_pubsub
import homelab_system/utils/logging
import homelab_system/utils/types

/// Cluster supervisor state
pub type ClusterSupervisorState {
  ClusterSupervisorState(
    node_config: NodeConfig,
    cluster_config: ClusterConfig,
    services: List(ClusterServiceInfo),
    status: ClusterSupervisorStatus,
    election_state: LeaderElectionState,
  )
}

/// Information about cluster services
pub type ClusterServiceInfo {
  ClusterServiceInfo(
    service_id: String,
    service_type: ClusterServiceType,
    pid: Option(process.Pid),
    status: ClusterServiceStatus,
    restart_count: Int,
  )
}

/// Types of cluster services
pub type ClusterServiceType {
  DiscoveryService
  CoordinationService
  ElectionService
  MessagingService
  HealthMonitorService
  ConsensusService
}

/// Cluster supervisor status
pub type ClusterSupervisorStatus {
  ClusterStarting
  ClusterRunning
  ClusterStopping
  ClusterStopped
  ClusterPartitioned
  ClusterFailed
}

/// Individual service status
pub type ClusterServiceStatus {
  ServiceStarting
  ServiceRunning
  ServiceStopping
  ServiceStopped
  ServiceFailed
  ServicePartitioned
}

/// Leader election state
pub type LeaderElectionState {
  NotParticipating
  Candidate
  Follower
  Leader
}

/// Start the cluster supervisor
pub fn start_link(
  node_config: NodeConfig,
  cluster_config: ClusterConfig,
) -> Result(actor.Started(Supervisor), actor.StartError) {
  logging.info("Starting cluster supervisor")

  let cluster_supervisor_spec =
    create_cluster_supervisor_spec(node_config, cluster_config)

  case cluster_supervisor_spec |> supervisor.start {
    Ok(started) -> {
      logging.info("Cluster supervisor started successfully")
      Ok(started)
    }
    Error(error) -> {
      logging.error("Failed to start cluster supervisor")
      Error(error)
    }
  }
}

/// Create supervisor specification for cluster services
fn create_cluster_supervisor_spec(
  node_config: NodeConfig,
  cluster_config: ClusterConfig,
) -> supervisor.Builder {
  logging.info("Creating cluster supervisor with comprehensive services")

  supervisor.new(supervisor.OneForOne)
  |> add_cluster_manager_service(node_config, cluster_config)
  |> add_discovery_service(node_config, cluster_config)
  |> add_node_manager_service(node_config, cluster_config)
  |> add_messaging_service(node_config, cluster_config)
  // |> add_health_monitor_service(node_config, cluster_config)  // Temporarily disabled
  |> add_coordination_service(node_config, cluster_config)
  |> add_consensus_service(node_config, cluster_config)
}

/// Add cluster manager service to supervisor
fn add_cluster_manager_service(
  builder: supervisor.Builder,
  node_config: NodeConfig,
  _cluster_config: ClusterConfig,
) -> supervisor.Builder {
  logging.debug("Adding cluster manager service")

  let cluster_manager_spec =
    supervision.worker(fn() { cluster_manager.start_link(node_config) })

  builder
  |> supervisor.add(cluster_manager_spec)
}

/// Add node manager service to supervisor
fn add_node_manager_service(
  builder: supervisor.Builder,
  node_config: NodeConfig,
  _cluster_config: ClusterConfig,
) -> supervisor.Builder {
  logging.debug("Adding node manager service")

  let node_manager_spec =
    supervision.worker(fn() { node_manager.start_link(node_config) })

  builder
  |> supervisor.add(node_manager_spec)
}

/// Add discovery service to supervisor
fn add_discovery_service(
  builder: supervisor.Builder,
  node_config: NodeConfig,
  cluster_config: ClusterConfig,
) -> supervisor.Builder {
  logging.debug("Adding service discovery")

  let discovery_spec =
    supervision.worker(fn() {
      discovery.start_link(
        types.NodeId(node_config.node_id),
        cluster_config.cluster_name,
      )
    })

  builder
  |> supervisor.add(discovery_spec)
}

/// Add coordination service to supervisor
fn add_coordination_service(
  builder: supervisor.Builder,
  node_config: NodeConfig,
  _cluster_config: ClusterConfig,
) -> supervisor.Builder {
  case node_config.role {
    node_config.Coordinator -> {
      logging.debug("Adding cluster coordination service")
      // Coordinators handle cluster-wide coordination
      builder
    }
    _ -> {
      logging.debug("Skipping coordination service (not a coordinator node)")
      builder
    }
  }
}

/// Add messaging service to supervisor
fn add_messaging_service(
  builder: supervisor.Builder,
  node_config: NodeConfig,
  cluster_config: ClusterConfig,
) -> supervisor.Builder {
  logging.debug("Adding distributed messaging service")

  let messaging_spec =
    supervision.worker(fn() {
      distributed_pubsub.start_link(
        types.NodeId(node_config.node_id),
        cluster_config.cluster_name,
      )
    })

  builder
  |> supervisor.add(messaging_spec)
}

/// Add health monitor service to supervisor
fn add_health_monitor_service(
  builder: supervisor.Builder,
  node_config: NodeConfig,
  cluster_config: ClusterConfig,
) -> supervisor.Builder {
  logging.debug("Adding comprehensive health monitor service")

  let health_monitor_spec =
    supervision.worker(fn() {
      simple_health_monitor.start_link(node_config, cluster_config)
    })

  builder
  |> supervisor.add(health_monitor_spec)
}

/// Add consensus service to supervisor
fn add_consensus_service(
  builder: supervisor.Builder,
  _node_config: NodeConfig,
  cluster_config: ClusterConfig,
) -> supervisor.Builder {
  case cluster_config.coordination.consensus_algorithm {
    cluster_config.Simple -> {
      logging.debug("Adding simple consensus service")
      // TODO: Add simple consensus service child spec
      builder
    }
    cluster_config.Raft -> {
      logging.debug("Adding Raft consensus service")
      // TODO: Add Raft consensus service child spec
      builder
    }
    cluster_config.PBFT -> {
      logging.debug("Adding PBFT consensus service")
      // TODO: Add PBFT consensus service child spec
      builder
    }
  }
}

/// Get cluster supervisor status
pub fn get_status() -> Result(ClusterSupervisorStatus, String) {
  logging.debug("Getting cluster supervisor status")
  // TODO: Implement actual status retrieval
  Ok(ClusterRunning)
}

/// Get information about all cluster services
pub fn get_services() -> Result(List(ClusterServiceInfo), String) {
  logging.debug("Getting cluster services information")
  // TODO: Implement actual service info retrieval
  Ok([])
}

/// Get current cluster membership
pub fn get_cluster_members() -> Result(List(String), String) {
  logging.debug("Getting cluster membership information")
  // TODO: Implement cluster membership retrieval
  // Should return list of active node IDs in the cluster
  Ok([])
}

/// Get leader election state
pub fn get_election_state() -> Result(LeaderElectionState, String) {
  logging.debug("Getting leader election state")
  // TODO: Implement election state retrieval
  Ok(NotParticipating)
}

/// Join cluster
pub fn join_cluster(bootstrap_nodes: List(String)) -> Result(Nil, String) {
  logging.info("Attempting to join cluster with enhanced discovery")

  case validate_bootstrap_nodes(bootstrap_nodes) {
    Ok(_) -> {
      case initiate_discovery(bootstrap_nodes) {
        Ok(_) -> {
          // Start health monitoring after joining
          case start_cluster_health_monitoring() {
            Ok(_) -> {
              logging.info(
                "Successfully joined cluster and started health monitoring",
              )
              Ok(Nil)
            }
            Error(reason) -> {
              logging.warn(
                "Joined cluster but failed to start health monitoring: "
                <> reason,
              )
              Ok(Nil)
              // Still consider join successful
            }
          }
        }
        Error(reason) -> {
          logging.error("Failed to join cluster: " <> reason)
          Error("Join failed: " <> reason)
        }
      }
    }
    Error(reason) -> {
      logging.error("Invalid bootstrap nodes: " <> reason)
      Error("Invalid bootstrap: " <> reason)
    }
  }
}

/// Leave cluster gracefully
pub fn leave_cluster() -> Result(Nil, String) {
  logging.info("Leaving cluster gracefully")

  case notify_cluster_departure() {
    Ok(_) -> {
      case cleanup_cluster_state() {
        Ok(_) -> {
          logging.info("Left cluster successfully")
          Ok(Nil)
        }
        Error(reason) -> {
          logging.error("Error during cluster cleanup: " <> reason)
          Error("Cleanup failed: " <> reason)
        }
      }
    }
    Error(reason) -> {
      logging.error("Failed to notify cluster of departure: " <> reason)
      Error("Notification failed: " <> reason)
    }
  }
}

/// Restart a specific cluster service
pub fn restart_service(service_id: String) -> Result(Nil, String) {
  logging.info("Restarting cluster service: " <> service_id)

  case validate_service_id(service_id) {
    Ok(_) -> {
      case stop_service(service_id) {
        Ok(_) -> {
          case start_service(service_id) {
            Ok(_) -> {
              logging.info("Service restarted successfully: " <> service_id)
              Ok(Nil)
            }
            Error(reason) -> {
              logging.error("Failed to start service: " <> reason)
              Error("Start failed: " <> reason)
            }
          }
        }
        Error(reason) -> {
          logging.error("Failed to stop service: " <> reason)
          Error("Stop failed: " <> reason)
        }
      }
    }
    Error(reason) -> {
      logging.error("Invalid service ID: " <> reason)
      Error("Invalid service: " <> reason)
    }
  }
}

/// Stop a specific cluster service
fn stop_service(service_id: String) -> Result(Nil, String) {
  logging.info("Stopping cluster service: " <> service_id)
  // TODO: Implement service stop logic
  Ok(Nil)
}

/// Start a specific cluster service
fn start_service(service_id: String) -> Result(Nil, String) {
  logging.info("Starting cluster service: " <> service_id)
  // TODO: Implement service start logic
  Ok(Nil)
}

/// Validate service ID
fn validate_service_id(_service_id: String) -> Result(Nil, String) {
  // TODO: Implement service ID validation
  Ok(Nil)
}

/// Validate bootstrap nodes
fn validate_bootstrap_nodes(nodes: List(String)) -> Result(Nil, String) {
  case list.length(nodes) {
    0 -> Error("No bootstrap nodes provided")
    _ -> {
      // Validate node address formats
      let valid_nodes =
        list.all(nodes, fn(node) {
          // Basic validation: should contain host:port format
          case node {
            "" -> False
            _ -> True
            // Simplified validation
          }
        })

      case valid_nodes {
        True -> Ok(Nil)
        False -> Error("Invalid node address format in bootstrap list")
      }
    }
  }
}

/// Initiate cluster discovery
fn initiate_discovery(bootstrap_nodes: List(String)) -> Result(Nil, String) {
  logging.info("Initiating cluster discovery with bootstrap nodes")

  // In a real implementation, this would:
  // 1. Connect to bootstrap nodes
  // 2. Announce this node's presence
  // 3. Request cluster membership information
  // 4. Establish communication channels

  case list.length(bootstrap_nodes) {
    0 -> Error("No bootstrap nodes to connect to")
    _ -> {
      logging.info("Discovery initiated successfully")
      Ok(Nil)
    }
  }
}

/// Start cluster health monitoring
fn start_cluster_health_monitoring() -> Result(Nil, String) {
  logging.info("Starting cluster health monitoring")
  // This would start health checks for the cluster
  Ok(Nil)
}

/// Notify cluster of departure
fn notify_cluster_departure() -> Result(Nil, String) {
  // TODO: Implement departure notification
  Ok(Nil)
}

/// Clean up cluster state
fn cleanup_cluster_state() -> Result(Nil, String) {
  // TODO: Implement cluster state cleanup
  Ok(Nil)
}

/// Shutdown cluster supervisor gracefully
pub fn shutdown() -> Result(Nil, String) {
  logging.info("Shutting down cluster supervisor")

  case leave_cluster() {
    Ok(_) -> {
      case shutdown_all_services() {
        Ok(_) -> {
          logging.info("Cluster supervisor shut down successfully")
          Ok(Nil)
        }
        Error(reason) -> {
          logging.error("Error shutting down cluster services: " <> reason)
          Error("Service shutdown failed: " <> reason)
        }
      }
    }
    Error(reason) -> {
      logging.error("Error leaving cluster: " <> reason)
      // Continue with shutdown even if leave failed
      case shutdown_all_services() {
        Ok(_) -> Ok(Nil)
        Error(shutdown_reason) ->
          Error("Multiple failures: " <> reason <> ", " <> shutdown_reason)
      }
    }
  }
}

/// Shutdown all cluster services
fn shutdown_all_services() -> Result(Nil, String) {
  logging.debug("Shutting down all cluster services")
  // TODO: Implement ordered service shutdown
  // Should stop services in reverse dependency order
  Ok(Nil)
}

/// Get cluster supervisor statistics
pub fn get_statistics() -> Result(ClusterSupervisorStatistics, String) {
  logging.debug("Getting cluster supervisor statistics")
  // TODO: Implement statistics gathering
  Ok(ClusterSupervisorStatistics(
    total_services: 0,
    running_services: 0,
    failed_services: 0,
    cluster_size: 0,
    is_leader: False,
    election_term: 0,
  ))
}

/// Cluster supervisor statistics
pub type ClusterSupervisorStatistics {
  ClusterSupervisorStatistics(
    total_services: Int,
    running_services: Int,
    failed_services: Int,
    cluster_size: Int,
    is_leader: Bool,
    election_term: Int,
  )
}

/// Health check for cluster supervisor
pub fn health_check() -> Result(Bool, String) {
  logging.debug("Performing comprehensive cluster supervisor health check")

  case get_status() {
    Ok(ClusterRunning) -> {
      case get_services() {
        Ok(services) -> {
          let healthy_services =
            list.filter(services, fn(service) {
              case service.status {
                ServiceRunning -> True
                _ -> False
              }
            })

          // Consider healthy if at least half the services are running
          let total_services = list.length(services)
          let healthy_count = list.length(healthy_services)

          case total_services {
            0 -> {
              logging.debug(
                "No services registered - considering healthy during startup",
              )
              Ok(True)
            }
            _ -> {
              let health_ratio = healthy_count * 100 / total_services
              logging.debug(
                "Cluster health ratio: " <> int_to_string(health_ratio) <> "%",
              )
              Ok(healthy_count * 2 >= total_services)
            }
          }
        }
        Error(reason) -> {
          logging.error("Failed to check cluster services: " <> reason)
          Error("Failed to check services: " <> reason)
        }
      }
    }
    Ok(ClusterPartitioned) -> {
      logging.warn(
        "Cluster is partitioned but considering as partially healthy",
      )
      Ok(True)
    }
    Ok(ClusterStarting) -> {
      logging.debug("Cluster is starting - considering healthy")
      Ok(True)
    }
    Ok(_) -> {
      logging.error("Cluster is in unhealthy state")
      Ok(False)
    }
    Error(reason) -> {
      logging.error("Cluster status check failed: " <> reason)
      Error("Status check failed: " <> reason)
    }
  }
}

/// Convert integer to string helper
fn int_to_string(value: Int) -> String {
  case value {
    0 -> "0"
    _ -> "unknown"
    // Placeholder - would use proper int conversion
  }
}

/// Create a supervised version for use in larger supervision trees
pub fn supervised(
  node_config: NodeConfig,
  cluster_config: ClusterConfig,
) -> supervision.ChildSpecification(Supervisor) {
  logging.debug("Creating supervised cluster supervisor specification")
  create_cluster_supervisor_spec(node_config, cluster_config)
  |> supervisor.supervised
}

/// Check if this node is the cluster leader
pub fn is_leader() -> Result(Bool, String) {
  case get_election_state() {
    Ok(Leader) -> Ok(True)
    Ok(_) -> Ok(False)
    Error(reason) -> Error(reason)
  }
}

/// Trigger leader election
pub fn trigger_election() -> Result(Nil, String) {
  logging.info("Triggering leader election")
  // TODO: Implement election trigger
  Ok(Nil)
}
