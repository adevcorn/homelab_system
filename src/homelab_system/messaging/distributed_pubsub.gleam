/// Distributed PubSub messaging system for the homelab cluster
/// Provides reliable message delivery, persistence, and cluster-wide synchronization
import gleam/dict.{type Dict}
import gleam/erlang/process
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/otp/actor
import gleam/string

import homelab_system/utils/logging
import homelab_system/utils/types.{type NodeId, type Timestamp}

/// Message priority levels
pub type MessagePriority {
  Critical
  High
  Medium
  Low
}

/// Message delivery guarantee types
pub type DeliveryGuarantee {
  AtMostOnce
  // Fire and forget
  AtLeastOnce
  // Retry until acknowledged
  ExactlyOnce
  // Deduplication and retry
}

/// Message acknowledgment status
pub type AckStatus {
  Pending
  Acknowledged
  Failed
  Expired
}

/// Topic pattern matching types
pub type TopicPattern {
  Exact(String)
  // Exact match: "system.health"
  Wildcard(String)
  // Wildcard: "system.*"
  MultiLevel(String)
  // Multi-level: "system.**"
  Regex(String)
  // Regex pattern
}

/// Message envelope containing metadata and payload
pub type MessageEnvelope {
  MessageEnvelope(
    id: String,
    // Unique message ID
    topic: String,
    // Target topic
    payload: String,
    // Message payload (JSON)
    sender_id: NodeId,
    // Sending node ID
    timestamp: Timestamp,
    // Creation timestamp
    priority: MessagePriority,
    // Message priority
    delivery_guarantee: DeliveryGuarantee,
    ttl: Option(Int),
    // Time to live in milliseconds
    retry_count: Int,
    // Current retry count
    max_retries: Int,
    // Maximum retry attempts
    correlation_id: Option(String),
    // For request-response patterns
    headers: Dict(String, String),
    // Custom headers
  )
}

/// Subscription configuration
pub type Subscription {
  Subscription(
    id: String,
    // Unique subscription ID
    node_id: NodeId,
    // Subscribing node
    pattern: TopicPattern,
    // Topic pattern to match
    handler: String,
    // Handler identifier
    delivery_guarantee: DeliveryGuarantee,
    filter_expression: Option(String),
    // Message filtering expression
    created_at: Timestamp,
    active: Bool,
  )
}

/// Message acknowledgment
pub type MessageAck {
  MessageAck(
    message_id: String,
    subscription_id: String,
    status: AckStatus,
    timestamp: Timestamp,
    error_details: Option(String),
  )
}

/// Persistent message store entry
pub type StoredMessage {
  StoredMessage(
    envelope: MessageEnvelope,
    ack_status: Dict(String, MessageAck),
    // subscription_id -> ack
    stored_at: Timestamp,
    expires_at: Option(Timestamp),
  )
}

/// Topic metadata and statistics
pub type TopicInfo {
  TopicInfo(
    name: String,
    subscriber_count: Int,
    message_count: Int,
    last_message_at: Option(Timestamp),
    retention_policy: RetentionPolicy,
  )
}

/// Message retention configuration
pub type RetentionPolicy {
  RetentionPolicy(
    max_messages: Option(Int),
    // Max messages to keep
    max_age: Option(Int),
    // Max age in milliseconds
    max_size: Option(Int),
    // Max size in bytes
  )
}

/// Distributed PubSub state
pub type DistributedPubSubState {
  DistributedPubSubState(
    node_id: NodeId,
    cluster_name: String,
    local_subscriptions: Dict(String, Subscription),
    message_store: Dict(String, StoredMessage),
    topic_info: Dict(String, TopicInfo),
    pending_acks: Dict(String, MessageAck),
    retry_queue: List(MessageEnvelope),
    delivery_workers: Int,
    max_message_size: Int,
    default_retention: RetentionPolicy,
    status: types.ServiceStatus,
  )
}

/// Messages for the distributed PubSub actor
pub type PubSubMessage {
  // Core PubSub operations
  Publish(MessageEnvelope)
  Subscribe(Subscription)
  Unsubscribe(String)

  // subscription_id
  // Message delivery and acknowledgment
  DeliverMessage(MessageEnvelope, String)
  // message, subscription_id
  AcknowledgeMessage(MessageAck)
  RetryFailedMessages

  // Topic management
  CreateTopic(String, RetentionPolicy)
  DeleteTopic(String)
  GetTopicInfo(String)
  ListTopics

  // Cluster synchronization
  SyncTopics
  SyncSubscriptions
  NodeJoined(NodeId)
  NodeLeft(NodeId)

  // Maintenance
  CleanupExpiredMessages
  CompactMessageStore
  GetStatistics
  Shutdown
}

/// Start the distributed PubSub system
pub fn start_link(
  node_id: NodeId,
  cluster_name: String,
) -> Result(actor.Started(process.Subject(PubSubMessage)), actor.StartError) {
  let default_retention =
    RetentionPolicy(
      max_messages: Some(10_000),
      max_age: Some(3_600_000),
      // 1 hour
      max_size: Some(100 * 1024 * 1024),
      // 100MB
    )

  let initial_state =
    DistributedPubSubState(
      node_id: node_id,
      cluster_name: cluster_name,
      local_subscriptions: dict.new(),
      message_store: dict.new(),
      topic_info: dict.new(),
      pending_acks: dict.new(),
      retry_queue: [],
      delivery_workers: 4,
      max_message_size: 1024 * 1024,
      // 1MB
      default_retention: default_retention,
      status: types.Starting,
    )

  case
    actor.new(initial_state)
    |> actor.on_message(handle_message)
    |> actor.start
  {
    Ok(started) -> {
      logging.info(
        "Distributed PubSub started for node: "
        <> types.node_id_to_string(node_id),
      )

      // Initialize distributed messaging
      case initialize_distributed_messaging(cluster_name) {
        Ok(_) -> {
          logging.info("Distributed messaging initialized successfully")
        }
        Error(err) -> {
          logging.warn("Failed to initialize distributed messaging: " <> err)
        }
      }

      Ok(started)
    }
    Error(err) -> {
      logging.error("Failed to start distributed PubSub")
      Error(err)
    }
  }
}

/// Initialize distributed messaging (local-only for now)
fn initialize_distributed_messaging(
  _cluster_name: String,
) -> Result(Nil, String) {
  // Initialize local-only messaging system
  // TODO: Add glubsub integration in future
  Ok(Nil)
}

/// Handle messages to the distributed PubSub actor
fn handle_message(
  state: DistributedPubSubState,
  message: PubSubMessage,
) -> actor.Next(DistributedPubSubState, PubSubMessage) {
  case message {
    Publish(envelope) -> handle_publish(envelope, state)
    Subscribe(subscription) -> handle_subscribe(subscription, state)
    Unsubscribe(subscription_id) -> handle_unsubscribe(subscription_id, state)
    DeliverMessage(envelope, subscription_id) ->
      handle_deliver_message(envelope, subscription_id, state)
    AcknowledgeMessage(ack) -> handle_acknowledge_message(ack, state)
    RetryFailedMessages -> handle_retry_failed_messages(state)
    CreateTopic(topic, retention) ->
      handle_create_topic(topic, retention, state)
    DeleteTopic(topic) -> handle_delete_topic(topic, state)
    GetTopicInfo(topic) -> handle_get_topic_info(topic, state)
    ListTopics -> handle_list_topics(state)
    SyncTopics -> handle_sync_topics(state)
    SyncSubscriptions -> handle_sync_subscriptions(state)
    NodeJoined(node_id) -> handle_node_joined(node_id, state)
    NodeLeft(node_id) -> handle_node_left(node_id, state)
    CleanupExpiredMessages -> handle_cleanup_expired_messages(state)
    CompactMessageStore -> handle_compact_message_store(state)
    GetStatistics -> handle_get_statistics(state)
    Shutdown -> handle_shutdown(state)
  }
}

/// Handle message publication
fn handle_publish(
  envelope: MessageEnvelope,
  state: DistributedPubSubState,
) -> actor.Next(DistributedPubSubState, PubSubMessage) {
  logging.debug("Publishing message to topic: " <> envelope.topic)

  // Validate message size
  let payload_size = string.length(envelope.payload)
  case payload_size > state.max_message_size {
    True -> {
      logging.warn(
        "Message too large: " <> int.to_string(payload_size) <> " bytes",
      )
      actor.continue(state)
    }
    False -> {
      // Store message for persistence and delivery tracking
      let stored_message =
        StoredMessage(
          envelope: envelope,
          ack_status: dict.new(),
          stored_at: types.now(),
          expires_at: calculate_expiry(envelope),
        )

      let updated_store =
        dict.insert(state.message_store, envelope.id, stored_message)

      // Update topic info
      let updated_topics = update_topic_stats(state.topic_info, envelope.topic)

      // Find matching subscriptions and deliver message
      let matching_subscriptions =
        find_matching_subscriptions(state.local_subscriptions, envelope.topic)

      // Deliver to local subscribers
      let updated_state =
        deliver_to_subscriptions(
          envelope,
          matching_subscriptions,
          DistributedPubSubState(
            ..state,
            message_store: updated_store,
            topic_info: updated_topics,
          ),
        )

      // Distribute to cluster (local-only for now)
      case distribute_message_to_cluster(envelope) {
        Ok(_) -> {
          logging.debug("Message queued for cluster distribution")
        }
        Error(err) -> {
          logging.warn(
            "Failed to queue message for cluster distribution: " <> err,
          )
        }
      }

      actor.continue(updated_state)
    }
  }
}

/// Handle subscription creation
fn handle_subscribe(
  subscription: Subscription,
  state: DistributedPubSubState,
) -> actor.Next(DistributedPubSubState, PubSubMessage) {
  logging.info("Creating subscription: " <> subscription.id)

  let updated_subscriptions =
    dict.insert(state.local_subscriptions, subscription.id, subscription)

  // Sync subscription with cluster
  case sync_subscription_to_cluster(subscription) {
    Ok(_) -> {
      logging.debug("Subscription synced to cluster")
    }
    Error(err) -> {
      logging.warn("Failed to sync subscription to cluster: " <> err)
    }
  }

  let new_state =
    DistributedPubSubState(..state, local_subscriptions: updated_subscriptions)

  actor.continue(new_state)
}

/// Handle subscription removal
fn handle_unsubscribe(
  subscription_id: String,
  state: DistributedPubSubState,
) -> actor.Next(DistributedPubSubState, PubSubMessage) {
  logging.info("Removing subscription: " <> subscription_id)

  let updated_subscriptions =
    dict.delete(state.local_subscriptions, subscription_id)

  let new_state =
    DistributedPubSubState(..state, local_subscriptions: updated_subscriptions)

  actor.continue(new_state)
}

/// Handle message delivery to specific subscription
fn handle_deliver_message(
  envelope: MessageEnvelope,
  subscription_id: String,
  state: DistributedPubSubState,
) -> actor.Next(DistributedPubSubState, PubSubMessage) {
  case dict.get(state.local_subscriptions, subscription_id) {
    Ok(subscription) -> {
      logging.debug(
        "Delivering message "
        <> envelope.id
        <> " to subscription "
        <> subscription_id,
      )

      // Apply message filtering if configured
      case apply_message_filter(envelope, subscription) {
        True -> {
          // Simulate message delivery to handler
          case simulate_message_delivery(envelope, subscription) {
            Ok(_) -> {
              // Message delivered successfully, create acknowledgment
              let ack =
                MessageAck(
                  message_id: envelope.id,
                  subscription_id: subscription_id,
                  status: Acknowledged,
                  timestamp: types.now(),
                  error_details: None,
                )

              // Update stored message with acknowledgment
              let updated_store =
                update_message_ack_status(
                  state.message_store,
                  envelope.id,
                  subscription_id,
                  ack,
                )

              let new_state =
                DistributedPubSubState(..state, message_store: updated_store)

              actor.continue(new_state)
            }
            Error(err) -> {
              logging.warn("Message delivery failed: " <> err)

              // Handle retry logic based on delivery guarantee
              case envelope.delivery_guarantee {
                AtLeastOnce | ExactlyOnce -> {
                  case envelope.retry_count < envelope.max_retries {
                    True -> {
                      // Add to retry queue
                      let retry_envelope =
                        MessageEnvelope(
                          ..envelope,
                          retry_count: envelope.retry_count + 1,
                        )

                      let new_state =
                        DistributedPubSubState(..state, retry_queue: [
                          retry_envelope,
                          ..state.retry_queue
                        ])

                      actor.continue(new_state)
                    }
                    False -> {
                      // Max retries exceeded, mark as failed
                      let failed_ack =
                        MessageAck(
                          message_id: envelope.id,
                          subscription_id: subscription_id,
                          status: Failed,
                          timestamp: types.now(),
                          error_details: Some(err),
                        )

                      let updated_store =
                        update_message_ack_status(
                          state.message_store,
                          envelope.id,
                          subscription_id,
                          failed_ack,
                        )

                      let new_state =
                        DistributedPubSubState(
                          ..state,
                          message_store: updated_store,
                        )

                      actor.continue(new_state)
                    }
                  }
                }
                AtMostOnce -> {
                  // No retry for fire-and-forget
                  actor.continue(state)
                }
              }
            }
          }
        }
        False -> {
          logging.debug("Message filtered out by subscription filter")
          actor.continue(state)
        }
      }
    }
    Error(_) -> {
      logging.warn("Subscription not found: " <> subscription_id)
      actor.continue(state)
    }
  }
}

/// Handle message acknowledgment
fn handle_acknowledge_message(
  ack: MessageAck,
  state: DistributedPubSubState,
) -> actor.Next(DistributedPubSubState, PubSubMessage) {
  logging.debug("Processing message acknowledgment: " <> ack.message_id)

  let updated_store =
    update_message_ack_status(
      state.message_store,
      ack.message_id,
      ack.subscription_id,
      ack,
    )

  let new_state = DistributedPubSubState(..state, message_store: updated_store)

  actor.continue(new_state)
}

/// Handle retry of failed messages
fn handle_retry_failed_messages(
  state: DistributedPubSubState,
) -> actor.Next(DistributedPubSubState, PubSubMessage) {
  logging.debug("Retrying failed messages")

  // Process retry queue
  case state.retry_queue {
    [] -> {
      logging.debug("No messages to retry")
      actor.continue(state)
    }
    [envelope, ..remaining] -> {
      // Find matching subscriptions for retry
      let matching_subscriptions =
        find_matching_subscriptions(state.local_subscriptions, envelope.topic)

      let updated_state =
        deliver_to_subscriptions(
          envelope,
          matching_subscriptions,
          DistributedPubSubState(..state, retry_queue: remaining),
        )

      actor.continue(updated_state)
    }
  }
}

/// Handle topic creation
fn handle_create_topic(
  topic: String,
  retention: RetentionPolicy,
  state: DistributedPubSubState,
) -> actor.Next(DistributedPubSubState, PubSubMessage) {
  logging.info("Creating topic: " <> topic)

  let topic_info =
    TopicInfo(
      name: topic,
      subscriber_count: 0,
      message_count: 0,
      last_message_at: None,
      retention_policy: retention,
    )

  let updated_topics = dict.insert(state.topic_info, topic, topic_info)

  let new_state = DistributedPubSubState(..state, topic_info: updated_topics)

  actor.continue(new_state)
}

/// Handle topic deletion
fn handle_delete_topic(
  topic: String,
  state: DistributedPubSubState,
) -> actor.Next(DistributedPubSubState, PubSubMessage) {
  logging.info("Deleting topic: " <> topic)

  let updated_topics = dict.delete(state.topic_info, topic)

  // Remove related subscriptions
  let updated_subscriptions =
    dict.filter(state.local_subscriptions, fn(_id, sub) {
      !topic_matches_pattern(topic, sub.pattern)
    })

  // Remove messages for this topic
  let updated_store =
    dict.filter(state.message_store, fn(_id, stored_msg) {
      stored_msg.envelope.topic != topic
    })

  let new_state =
    DistributedPubSubState(
      ..state,
      topic_info: updated_topics,
      local_subscriptions: updated_subscriptions,
      message_store: updated_store,
    )

  actor.continue(new_state)
}

/// Handle get topic info request
fn handle_get_topic_info(
  topic: String,
  state: DistributedPubSubState,
) -> actor.Next(DistributedPubSubState, PubSubMessage) {
  case dict.get(state.topic_info, topic) {
    Ok(info) -> {
      logging.debug("Topic info found for: " <> topic)
      let _ = info
      // Use the info variable
      actor.continue(state)
    }
    Error(_) -> {
      logging.debug("Topic not found: " <> topic)
      actor.continue(state)
    }
  }
}

/// Handle list topics request
fn handle_list_topics(
  state: DistributedPubSubState,
) -> actor.Next(DistributedPubSubState, PubSubMessage) {
  let topic_count = dict.size(state.topic_info)
  logging.debug("Listing topics, count: " <> int.to_string(topic_count))

  actor.continue(state)
}

/// Handle topic synchronization
fn handle_sync_topics(
  state: DistributedPubSubState,
) -> actor.Next(DistributedPubSubState, PubSubMessage) {
  logging.debug("Synchronizing topics with cluster")

  // TODO: Implement distributed topic synchronization
  actor.continue(state)
}

/// Handle subscription synchronization
fn handle_sync_subscriptions(
  state: DistributedPubSubState,
) -> actor.Next(DistributedPubSubState, PubSubMessage) {
  logging.debug("Synchronizing subscriptions with cluster")

  // TODO: Implement distributed subscription synchronization
  actor.continue(state)
}

/// Handle node joined event
fn handle_node_joined(
  node_id: NodeId,
  state: DistributedPubSubState,
) -> actor.Next(DistributedPubSubState, PubSubMessage) {
  logging.info("Node joined: " <> types.node_id_to_string(node_id))

  // Sync our state with the new node
  // TODO: Implement node synchronization

  actor.continue(state)
}

/// Handle node left event
fn handle_node_left(
  node_id: NodeId,
  state: DistributedPubSubState,
) -> actor.Next(DistributedPubSubState, PubSubMessage) {
  logging.info("Node left: " <> types.node_id_to_string(node_id))

  // Clean up subscriptions from the departed node
  let updated_subscriptions =
    dict.filter(state.local_subscriptions, fn(_id, sub) {
      sub.node_id != node_id
    })

  let new_state =
    DistributedPubSubState(..state, local_subscriptions: updated_subscriptions)

  actor.continue(new_state)
}

/// Handle expired message cleanup
fn handle_cleanup_expired_messages(
  state: DistributedPubSubState,
) -> actor.Next(DistributedPubSubState, PubSubMessage) {
  logging.debug("Cleaning up expired messages")

  let current_time = types.now()
  let updated_store =
    dict.filter(state.message_store, fn(_id, stored_msg) {
      case stored_msg.expires_at {
        Some(expiry) -> {
          case current_time, expiry {
            types.Timestamp(current), types.Timestamp(exp) -> current < exp
          }
        }
        None -> True
        // No expiry, keep the message
      }
    })

  let new_state = DistributedPubSubState(..state, message_store: updated_store)

  actor.continue(new_state)
}

/// Handle message store compaction
fn handle_compact_message_store(
  state: DistributedPubSubState,
) -> actor.Next(DistributedPubSubState, PubSubMessage) {
  logging.debug("Compacting message store")

  // Remove fully acknowledged messages
  let updated_store =
    dict.filter(state.message_store, fn(_id, stored_msg) {
      !is_message_fully_acknowledged(stored_msg, state.local_subscriptions)
    })

  let new_state = DistributedPubSubState(..state, message_store: updated_store)

  actor.continue(new_state)
}

/// Handle statistics request
fn handle_get_statistics(
  state: DistributedPubSubState,
) -> actor.Next(DistributedPubSubState, PubSubMessage) {
  let message_count = dict.size(state.message_store)
  let subscription_count = dict.size(state.local_subscriptions)
  let topic_count = dict.size(state.topic_info)

  logging.debug(
    "PubSub statistics - Messages: "
    <> int.to_string(message_count)
    <> ", Subscriptions: "
    <> int.to_string(subscription_count)
    <> ", Topics: "
    <> int.to_string(topic_count),
  )

  actor.continue(state)
}

/// Handle shutdown
fn handle_shutdown(
  _state: DistributedPubSubState,
) -> actor.Next(DistributedPubSubState, PubSubMessage) {
  logging.info("Shutting down distributed PubSub")

  // Cleanup distributed messaging
  logging.debug("Distributed messaging cleanup completed")

  actor.stop()
}

/// Helper functions
/// Calculate message expiry timestamp
fn calculate_expiry(envelope: MessageEnvelope) -> Option(Timestamp) {
  case envelope.ttl {
    Some(ttl) -> {
      case envelope.timestamp {
        types.Timestamp(ts) -> Some(types.Timestamp(ts + ttl))
      }
    }
    None -> None
  }
}

/// Update topic statistics
fn update_topic_stats(
  topics: Dict(String, TopicInfo),
  topic_name: String,
) -> Dict(String, TopicInfo) {
  case dict.get(topics, topic_name) {
    Ok(topic_info) -> {
      let updated_info =
        TopicInfo(
          ..topic_info,
          message_count: topic_info.message_count + 1,
          last_message_at: Some(types.now()),
        )
      dict.insert(topics, topic_name, updated_info)
    }
    Error(_) -> {
      // Create new topic info
      let new_info =
        TopicInfo(
          name: topic_name,
          subscriber_count: 0,
          message_count: 1,
          last_message_at: Some(types.now()),
          retention_policy: RetentionPolicy(
            max_messages: Some(1000),
            max_age: Some(3_600_000),
            max_size: Some(10 * 1024 * 1024),
          ),
        )
      dict.insert(topics, topic_name, new_info)
    }
  }
}

/// Find subscriptions that match a topic
fn find_matching_subscriptions(
  subscriptions: Dict(String, Subscription),
  topic: String,
) -> List(Subscription) {
  dict.values(subscriptions)
  |> list.filter(fn(sub) { topic_matches_pattern(topic, sub.pattern) })
}

/// Check if topic matches a pattern
fn topic_matches_pattern(topic: String, pattern: TopicPattern) -> Bool {
  case pattern {
    Exact(pattern_str) -> topic == pattern_str
    Wildcard(pattern_str) -> {
      // Simple wildcard matching: "system.*" matches "system.health"
      case string.ends_with(pattern_str, "*") {
        True -> {
          let prefix = string.drop_end(pattern_str, 1)
          string.starts_with(topic, prefix)
        }
        False -> topic == pattern_str
      }
    }
    MultiLevel(pattern_str) -> {
      // Multi-level wildcard: "system.**" matches "system.health.cpu"
      case string.ends_with(pattern_str, "**") {
        True -> {
          let prefix = string.drop_end(pattern_str, 2)
          string.starts_with(topic, prefix)
        }
        False -> topic == pattern_str
      }
    }
    Regex(_pattern_str) -> {
      // TODO: Implement regex matching
      False
    }
  }
}

/// Deliver message to multiple subscriptions
fn deliver_to_subscriptions(
  envelope: MessageEnvelope,
  subscriptions: List(Subscription),
  state: DistributedPubSubState,
) -> DistributedPubSubState {
  list.fold(subscriptions, state, fn(acc_state, subscription) {
    // Simulate delivery by updating state
    // In a real implementation, this would send messages to handlers
    let _ = envelope
    let _ = subscription
    acc_state
  })
}

/// Apply message filtering based on subscription filter
fn apply_message_filter(
  _envelope: MessageEnvelope,
  subscription: Subscription,
) -> Bool {
  case subscription.filter_expression {
    Some(_filter) -> {
      // TODO: Implement message filtering based on expression
      True
    }
    None -> True
  }
}

/// Simulate message delivery to subscription handler
fn simulate_message_delivery(
  _envelope: MessageEnvelope,
  _subscription: Subscription,
) -> Result(Nil, String) {
  // Simulate successful delivery
  Ok(Nil)
}

/// Update message acknowledgment status
fn update_message_ack_status(
  store: Dict(String, StoredMessage),
  message_id: String,
  subscription_id: String,
  ack: MessageAck,
) -> Dict(String, StoredMessage) {
  case dict.get(store, message_id) {
    Ok(stored_msg) -> {
      let updated_acks =
        dict.insert(stored_msg.ack_status, subscription_id, ack)
      let updated_msg = StoredMessage(..stored_msg, ack_status: updated_acks)
      dict.insert(store, message_id, updated_msg)
    }
    Error(_) -> store
  }
}

/// Check if message is fully acknowledged by all relevant subscriptions
fn is_message_fully_acknowledged(
  _stored_msg: StoredMessage,
  _subscriptions: Dict(String, Subscription),
) -> Bool {
  // TODO: Implement proper acknowledgment checking
  False
}

/// Distribute message to cluster (local-only implementation)
fn distribute_message_to_cluster(
  envelope: MessageEnvelope,
) -> Result(Nil, String) {
  // Local-only implementation for now
  // TODO: Implement actual cluster distribution with glubsub
  logging.debug("Message queued for cluster distribution: " <> envelope.topic)
  Ok(Nil)
}

/// Sync subscription to cluster (local-only implementation)
fn sync_subscription_to_cluster(
  subscription: Subscription,
) -> Result(Nil, String) {
  let topic_pattern = case subscription.pattern {
    Exact(pattern) -> pattern
    Wildcard(pattern) -> pattern
    MultiLevel(pattern) -> pattern
    Regex(pattern) -> pattern
  }

  // Local-only implementation for now
  // TODO: Implement actual cluster subscription sync with glubsub
  logging.debug("Subscription queued for cluster sync: " <> topic_pattern)
  Ok(Nil)
}

/// Public API functions
/// Publish a message
pub fn publish(
  pubsub: actor.Started(process.Subject(PubSubMessage)),
  envelope: MessageEnvelope,
) -> Nil {
  process.send(pubsub.data, Publish(envelope))
}

/// Subscribe to a topic pattern
pub fn subscribe(
  pubsub: actor.Started(process.Subject(PubSubMessage)),
  subscription: Subscription,
) -> Nil {
  process.send(pubsub.data, Subscribe(subscription))
}

/// Unsubscribe from a topic
pub fn unsubscribe(
  pubsub: actor.Started(process.Subject(PubSubMessage)),
  subscription_id: String,
) -> Nil {
  process.send(pubsub.data, Unsubscribe(subscription_id))
}

/// Acknowledge a message
pub fn acknowledge_message(
  pubsub: actor.Started(process.Subject(PubSubMessage)),
  ack: MessageAck,
) -> Nil {
  process.send(pubsub.data, AcknowledgeMessage(ack))
}

/// Create a topic with retention policy
pub fn create_topic(
  pubsub: actor.Started(process.Subject(PubSubMessage)),
  topic: String,
  retention: RetentionPolicy,
) -> Nil {
  process.send(pubsub.data, CreateTopic(topic, retention))
}

/// Delete a topic
pub fn delete_topic(
  pubsub: actor.Started(process.Subject(PubSubMessage)),
  topic: String,
) -> Nil {
  process.send(pubsub.data, DeleteTopic(topic))
}

/// Get topic information
pub fn get_topic_info(
  pubsub: actor.Started(process.Subject(PubSubMessage)),
  topic: String,
) -> Nil {
  process.send(pubsub.data, GetTopicInfo(topic))
}

/// List all topics
pub fn list_topics(pubsub: actor.Started(process.Subject(PubSubMessage))) -> Nil {
  process.send(pubsub.data, ListTopics)
}

/// Trigger retry of failed messages
pub fn retry_failed_messages(
  pubsub: actor.Started(process.Subject(PubSubMessage)),
) -> Nil {
  process.send(pubsub.data, RetryFailedMessages)
}

/// Synchronize topics with cluster
pub fn sync_topics(pubsub: actor.Started(process.Subject(PubSubMessage))) -> Nil {
  process.send(pubsub.data, SyncTopics)
}

/// Synchronize subscriptions with cluster
pub fn sync_subscriptions(
  pubsub: actor.Started(process.Subject(PubSubMessage)),
) -> Nil {
  process.send(pubsub.data, SyncSubscriptions)
}

/// Cleanup expired messages
pub fn cleanup_expired_messages(
  pubsub: actor.Started(process.Subject(PubSubMessage)),
) -> Nil {
  process.send(pubsub.data, CleanupExpiredMessages)
}

/// Compact message store
pub fn compact_message_store(
  pubsub: actor.Started(process.Subject(PubSubMessage)),
) -> Nil {
  process.send(pubsub.data, CompactMessageStore)
}

/// Get system statistics
pub fn get_statistics(
  pubsub: actor.Started(process.Subject(PubSubMessage)),
) -> Nil {
  process.send(pubsub.data, GetStatistics)
}

/// Shutdown the PubSub system
pub fn shutdown(pubsub: actor.Started(process.Subject(PubSubMessage))) -> Nil {
  process.send(pubsub.data, Shutdown)
}

/// Utility functions for creating message envelopes and subscriptions
/// Create a new message envelope
pub fn new_message_envelope(
  id: String,
  topic: String,
  payload: String,
  sender_id: NodeId,
) -> MessageEnvelope {
  MessageEnvelope(
    id: id,
    topic: topic,
    payload: payload,
    sender_id: sender_id,
    timestamp: types.now(),
    priority: Medium,
    delivery_guarantee: AtLeastOnce,
    ttl: None,
    retry_count: 0,
    max_retries: 3,
    correlation_id: None,
    headers: dict.new(),
  )
}

/// Create a new subscription
pub fn new_subscription(
  id: String,
  node_id: NodeId,
  pattern: TopicPattern,
  handler: String,
) -> Subscription {
  Subscription(
    id: id,
    node_id: node_id,
    pattern: pattern,
    handler: handler,
    delivery_guarantee: AtLeastOnce,
    filter_expression: None,
    created_at: types.now(),
    active: True,
  )
}

/// Create a default retention policy
pub fn default_retention_policy() -> RetentionPolicy {
  RetentionPolicy(
    max_messages: Some(1000),
    max_age: Some(3_600_000),
    // 1 hour
    max_size: Some(10 * 1024 * 1024),
    // 10MB
  )
}

/// Create a message acknowledgment
pub fn new_message_ack(
  message_id: String,
  subscription_id: String,
  status: AckStatus,
) -> MessageAck {
  MessageAck(
    message_id: message_id,
    subscription_id: subscription_id,
    status: status,
    timestamp: types.now(),
    error_details: None,
  )
}

/// Priority helpers
pub fn priority_to_string(priority: MessagePriority) -> String {
  case priority {
    Critical -> "critical"
    High -> "high"
    Medium -> "medium"
    Low -> "low"
  }
}

pub fn string_to_priority(s: String) -> Result(MessagePriority, String) {
  case s {
    "critical" -> Ok(Critical)
    "high" -> Ok(High)
    "medium" -> Ok(Medium)
    "low" -> Ok(Low)
    _ -> Error("Invalid priority: " <> s)
  }
}

/// Delivery guarantee helpers
pub fn delivery_guarantee_to_string(guarantee: DeliveryGuarantee) -> String {
  case guarantee {
    AtMostOnce -> "at_most_once"
    AtLeastOnce -> "at_least_once"
    ExactlyOnce -> "exactly_once"
  }
}

pub fn string_to_delivery_guarantee(
  s: String,
) -> Result(DeliveryGuarantee, String) {
  case s {
    "at_most_once" -> Ok(AtMostOnce)
    "at_least_once" -> Ok(AtLeastOnce)
    "exactly_once" -> Ok(ExactlyOnce)
    _ -> Error("Invalid delivery guarantee: " <> s)
  }
}
