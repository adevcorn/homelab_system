//// Homelab System Messaging PubSub Module
////
//// This module provides publish-subscribe messaging functionality for internal
//// communication between homelab system components.
////
//// Features:
//// - Topic-based message publishing and subscription
//// - Event broadcasting for system events
//// - Inter-component communication
//// - Message routing and filtering

import gleam/dict.{type Dict}
import gleam/list

/// Message topic type
pub type Topic =
  String

/// Message payload type
pub type Message {
  SystemEvent(event_type: String, data: String)
  NodeEvent(node_id: String, event_type: String, data: String)
  ClusterEvent(cluster_id: String, event_type: String, data: String)
  HealthEvent(component: String, status: String, details: String)
  ConfigEvent(key: String, old_value: String, new_value: String)
}

/// Subscriber callback function type
pub type Subscriber =
  fn(Topic, Message) -> Nil

/// PubSub system state
pub type PubSubSystem {
  PubSubSystem(
    topics: Dict(Topic, List(Subscriber)),
    active: Bool,
    message_count: Int,
  )
}

/// Create a new PubSub system
pub fn new() -> PubSubSystem {
  PubSubSystem(topics: dict.new(), active: True, message_count: 0)
}

/// Start the PubSub system
pub fn start(system: PubSubSystem) -> Result(PubSubSystem, String) {
  case system.active {
    True -> Ok(PubSubSystem(..system, active: True))
    False -> Ok(PubSubSystem(..system, active: True))
  }
}

/// Stop the PubSub system
pub fn stop(system: PubSubSystem) -> PubSubSystem {
  PubSubSystem(..system, active: False)
}

/// Subscribe to a topic
pub fn subscribe(
  system: PubSubSystem,
  topic: Topic,
  subscriber: Subscriber,
) -> PubSubSystem {
  let updated_topics = case dict.get(system.topics, topic) {
    Ok(existing_subscribers) -> {
      dict.insert(system.topics, topic, [subscriber, ..existing_subscribers])
    }
    Error(_) -> {
      dict.insert(system.topics, topic, [subscriber])
    }
  }

  PubSubSystem(..system, topics: updated_topics)
}

/// Unsubscribe from a topic (simplified - removes all subscribers for now)
pub fn unsubscribe(system: PubSubSystem, topic: Topic) -> PubSubSystem {
  let updated_topics = dict.delete(system.topics, topic)
  PubSubSystem(..system, topics: updated_topics)
}

/// Publish a message to a topic
pub fn publish(
  system: PubSubSystem,
  topic: Topic,
  message: Message,
) -> PubSubSystem {
  case system.active {
    False -> system
    True -> {
      case dict.get(system.topics, topic) {
        Ok(subscribers) -> {
          // Notify all subscribers
          list.each(subscribers, fn(subscriber) { subscriber(topic, message) })
          PubSubSystem(..system, message_count: system.message_count + 1)
        }
        Error(_) -> {
          // No subscribers for this topic
          system
        }
      }
    }
  }
}

/// Broadcast a message to all topics
pub fn broadcast(system: PubSubSystem, message: Message) -> PubSubSystem {
  case system.active {
    False -> system
    True -> {
      let topics = dict.keys(system.topics)
      list.fold(topics, system, fn(acc_system, topic) {
        publish(acc_system, topic, message)
      })
    }
  }
}

/// Get list of active topics
pub fn get_topics(system: PubSubSystem) -> List(Topic) {
  dict.keys(system.topics)
}

/// Get subscriber count for a topic
pub fn get_subscriber_count(system: PubSubSystem, topic: Topic) -> Int {
  case dict.get(system.topics, topic) {
    Ok(subscribers) -> list.length(subscribers)
    Error(_) -> 0
  }
}

/// Get total message count
pub fn get_message_count(system: PubSubSystem) -> Int {
  system.message_count
}

/// Check if system is active
pub fn is_active(system: PubSubSystem) -> Bool {
  system.active
}

// Predefined topic constants for common system events

pub const system_events = "homelab.system.events"

pub const node_events = "homelab.node.events"

pub const cluster_events = "homelab.cluster.events"

pub const health_events = "homelab.health.events"

pub const config_events = "homelab.config.events"

pub const api_events = "homelab.api.events"

pub const metrics_events = "homelab.metrics.events"

// Helper functions for creating common message types

/// Create a system startup event message
pub fn system_startup_message(version: String) -> Message {
  SystemEvent(event_type: "startup", data: "version=" <> version)
}

/// Create a system shutdown event message
pub fn system_shutdown_message(reason: String) -> Message {
  SystemEvent(event_type: "shutdown", data: "reason=" <> reason)
}

/// Create a node join event message
pub fn node_join_message(node_id: String, cluster_id: String) -> Message {
  NodeEvent(
    node_id: node_id,
    event_type: "join",
    data: "cluster=" <> cluster_id,
  )
}

/// Create a node leave event message
pub fn node_leave_message(node_id: String, reason: String) -> Message {
  NodeEvent(node_id: node_id, event_type: "leave", data: "reason=" <> reason)
}

/// Create a health status message
pub fn health_status_message(
  component: String,
  status: String,
  details: String,
) -> Message {
  HealthEvent(component: component, status: status, details: details)
}

/// Create a configuration change message
pub fn config_change_message(
  key: String,
  old_value: String,
  new_value: String,
) -> Message {
  ConfigEvent(key: key, old_value: old_value, new_value: new_value)
}

/// Format a message as a string for logging
pub fn message_to_string(message: Message) -> String {
  case message {
    SystemEvent(event_type, data) ->
      "SystemEvent{type: " <> event_type <> ", data: " <> data <> "}"
    NodeEvent(node_id, event_type, data) ->
      "NodeEvent{node: "
      <> node_id
      <> ", type: "
      <> event_type
      <> ", data: "
      <> data
      <> "}"
    ClusterEvent(cluster_id, event_type, data) ->
      "ClusterEvent{cluster: "
      <> cluster_id
      <> ", type: "
      <> event_type
      <> ", data: "
      <> data
      <> "}"
    HealthEvent(component, status, details) ->
      "HealthEvent{component: "
      <> component
      <> ", status: "
      <> status
      <> ", details: "
      <> details
      <> "}"
    ConfigEvent(key, old_value, new_value) ->
      "ConfigEvent{key: "
      <> key
      <> ", old: "
      <> old_value
      <> ", new: "
      <> new_value
      <> "}"
  }
}
