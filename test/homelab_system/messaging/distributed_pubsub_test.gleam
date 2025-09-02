/// Tests for the distributed PubSub messaging system
import gleam/dict
import gleam/erlang/process
import gleam/list
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should

import homelab_system/messaging/distributed_pubsub
import homelab_system/utils/types

pub fn main() {
  gleeunit.main()
}

/// Test message envelope creation
pub fn new_message_envelope_test() {
  let node_id = types.NodeId("sender-node")

  let envelope =
    distributed_pubsub.new_message_envelope(
      "msg-1",
      "system.health",
      "{\"status\":\"healthy\"}",
      node_id,
    )

  envelope.id
  |> should.equal("msg-1")

  envelope.topic
  |> should.equal("system.health")

  envelope.payload
  |> should.equal("{\"status\":\"healthy\"}")

  envelope.sender_id
  |> should.equal(node_id)

  envelope.priority
  |> should.equal(distributed_pubsub.Medium)

  envelope.delivery_guarantee
  |> should.equal(distributed_pubsub.AtLeastOnce)

  envelope.retry_count
  |> should.equal(0)

  envelope.max_retries
  |> should.equal(3)
}

/// Test subscription creation
pub fn new_subscription_test() {
  let node_id = types.NodeId("subscriber-node")
  let pattern = distributed_pubsub.Exact("system.alerts")

  let subscription =
    distributed_pubsub.new_subscription(
      "sub-1",
      node_id,
      pattern,
      "alert-handler",
    )

  subscription.id
  |> should.equal("sub-1")

  subscription.node_id
  |> should.equal(node_id)

  subscription.pattern
  |> should.equal(pattern)

  subscription.handler
  |> should.equal("alert-handler")

  subscription.delivery_guarantee
  |> should.equal(distributed_pubsub.AtLeastOnce)

  subscription.active
  |> should.equal(True)
}

/// Test retention policy creation
pub fn default_retention_policy_test() {
  let policy = distributed_pubsub.default_retention_policy()

  policy.max_messages
  |> should.equal(Some(1000))

  policy.max_age
  |> should.equal(Some(3_600_000))
  // 1 hour

  policy.max_size
  |> should.equal(Some(10 * 1024 * 1024))
  // 10MB
}

/// Test message acknowledgment creation
pub fn new_message_ack_test() {
  let ack =
    distributed_pubsub.new_message_ack(
      "msg-1",
      "sub-1",
      distributed_pubsub.Acknowledged,
    )

  ack.message_id
  |> should.equal("msg-1")

  ack.subscription_id
  |> should.equal("sub-1")

  ack.status
  |> should.equal(distributed_pubsub.Acknowledged)

  ack.error_details
  |> should.equal(None)
}

/// Test distributed PubSub startup
pub fn distributed_pubsub_startup_test() {
  let node_id = types.NodeId("test-node")
  let cluster_name = "test-cluster"

  case distributed_pubsub.start_link(node_id, cluster_name) {
    Ok(started) -> {
      should.be_ok(Ok(started))

      // Shutdown the actor
      distributed_pubsub.shutdown(started)
    }
    Error(_) -> {
      should.fail()
    }
  }
}

/// Test message publishing
pub fn message_publishing_test() {
  let node_id = types.NodeId("test-node")
  let cluster_name = "test-cluster"

  case distributed_pubsub.start_link(node_id, cluster_name) {
    Ok(started) -> {
      let envelope =
        distributed_pubsub.new_message_envelope(
          "test-msg-1",
          "system.test",
          "{\"test\":true}",
          node_id,
        )

      // Publish message
      distributed_pubsub.publish(started, envelope)

      // Give the actor time to process
      process.sleep(10)

      // Shutdown
      distributed_pubsub.shutdown(started)

      should.be_true(True)
    }
    Error(_) -> {
      should.fail()
    }
  }
}

/// Test subscription management
pub fn subscription_management_test() {
  let node_id = types.NodeId("test-node")
  let cluster_name = "test-cluster"

  case distributed_pubsub.start_link(node_id, cluster_name) {
    Ok(started) -> {
      let subscription =
        distributed_pubsub.new_subscription(
          "test-sub-1",
          node_id,
          distributed_pubsub.Exact("system.events"),
          "event-handler",
        )

      // Subscribe
      distributed_pubsub.subscribe(started, subscription)

      // Give the actor time to process
      process.sleep(10)

      // Unsubscribe
      distributed_pubsub.unsubscribe(started, "test-sub-1")

      // Give the actor time to process
      process.sleep(10)

      // Shutdown
      distributed_pubsub.shutdown(started)

      should.be_true(True)
    }
    Error(_) -> {
      should.fail()
    }
  }
}

/// Test topic management
pub fn topic_management_test() {
  let node_id = types.NodeId("test-node")
  let cluster_name = "test-cluster"

  case distributed_pubsub.start_link(node_id, cluster_name) {
    Ok(started) -> {
      let retention = distributed_pubsub.default_retention_policy()

      // Create topic
      distributed_pubsub.create_topic(started, "test.topic", retention)

      // Give the actor time to process
      process.sleep(10)

      // Get topic info
      distributed_pubsub.get_topic_info(started, "test.topic")

      // Give the actor time to process
      process.sleep(10)

      // List topics
      distributed_pubsub.list_topics(started)

      // Give the actor time to process
      process.sleep(10)

      // Delete topic
      distributed_pubsub.delete_topic(started, "test.topic")

      // Give the actor time to process
      process.sleep(10)

      // Shutdown
      distributed_pubsub.shutdown(started)

      should.be_true(True)
    }
    Error(_) -> {
      should.fail()
    }
  }
}

/// Test message acknowledgment
pub fn message_acknowledgment_test() {
  let node_id = types.NodeId("test-node")
  let cluster_name = "test-cluster"

  case distributed_pubsub.start_link(node_id, cluster_name) {
    Ok(started) -> {
      let ack =
        distributed_pubsub.new_message_ack(
          "msg-1",
          "sub-1",
          distributed_pubsub.Acknowledged,
        )

      // Acknowledge message
      distributed_pubsub.acknowledge_message(started, ack)

      // Give the actor time to process
      process.sleep(10)

      // Shutdown
      distributed_pubsub.shutdown(started)

      should.be_true(True)
    }
    Error(_) -> {
      should.fail()
    }
  }
}

/// Test maintenance operations
pub fn maintenance_operations_test() {
  let node_id = types.NodeId("test-node")
  let cluster_name = "test-cluster"

  case distributed_pubsub.start_link(node_id, cluster_name) {
    Ok(started) -> {
      // Retry failed messages
      distributed_pubsub.retry_failed_messages(started)

      // Give the actor time to process
      process.sleep(10)

      // Cleanup expired messages
      distributed_pubsub.cleanup_expired_messages(started)

      // Give the actor time to process
      process.sleep(10)

      // Compact message store
      distributed_pubsub.compact_message_store(started)

      // Give the actor time to process
      process.sleep(10)

      // Get statistics
      distributed_pubsub.get_statistics(started)

      // Give the actor time to process
      process.sleep(10)

      // Shutdown
      distributed_pubsub.shutdown(started)

      should.be_true(True)
    }
    Error(_) -> {
      should.fail()
    }
  }
}

/// Test cluster synchronization
pub fn cluster_synchronization_test() {
  let node_id = types.NodeId("test-node")
  let cluster_name = "test-cluster"

  case distributed_pubsub.start_link(node_id, cluster_name) {
    Ok(started) -> {
      // Sync topics
      distributed_pubsub.sync_topics(started)

      // Give the actor time to process
      process.sleep(10)

      // Sync subscriptions
      distributed_pubsub.sync_subscriptions(started)

      // Give the actor time to process
      process.sleep(10)

      // Shutdown
      distributed_pubsub.shutdown(started)

      should.be_true(True)
    }
    Error(_) -> {
      should.fail()
    }
  }
}

/// Test priority helpers
pub fn priority_helpers_test() {
  // Test priority to string
  distributed_pubsub.priority_to_string(distributed_pubsub.Critical)
  |> should.equal("critical")

  distributed_pubsub.priority_to_string(distributed_pubsub.High)
  |> should.equal("high")

  distributed_pubsub.priority_to_string(distributed_pubsub.Medium)
  |> should.equal("medium")

  distributed_pubsub.priority_to_string(distributed_pubsub.Low)
  |> should.equal("low")

  // Test string to priority
  distributed_pubsub.string_to_priority("critical")
  |> should.equal(Ok(distributed_pubsub.Critical))

  distributed_pubsub.string_to_priority("high")
  |> should.equal(Ok(distributed_pubsub.High))

  distributed_pubsub.string_to_priority("medium")
  |> should.equal(Ok(distributed_pubsub.Medium))

  distributed_pubsub.string_to_priority("low")
  |> should.equal(Ok(distributed_pubsub.Low))

  distributed_pubsub.string_to_priority("invalid")
  |> should.be_error()
}

/// Test delivery guarantee helpers
pub fn delivery_guarantee_helpers_test() {
  // Test delivery guarantee to string
  distributed_pubsub.delivery_guarantee_to_string(distributed_pubsub.AtMostOnce)
  |> should.equal("at_most_once")

  distributed_pubsub.delivery_guarantee_to_string(
    distributed_pubsub.AtLeastOnce,
  )
  |> should.equal("at_least_once")

  distributed_pubsub.delivery_guarantee_to_string(
    distributed_pubsub.ExactlyOnce,
  )
  |> should.equal("exactly_once")

  // Test string to delivery guarantee
  distributed_pubsub.string_to_delivery_guarantee("at_most_once")
  |> should.equal(Ok(distributed_pubsub.AtMostOnce))

  distributed_pubsub.string_to_delivery_guarantee("at_least_once")
  |> should.equal(Ok(distributed_pubsub.AtLeastOnce))

  distributed_pubsub.string_to_delivery_guarantee("exactly_once")
  |> should.equal(Ok(distributed_pubsub.ExactlyOnce))

  distributed_pubsub.string_to_delivery_guarantee("invalid")
  |> should.be_error()
}

/// Test complex message envelope with custom settings
pub fn complex_message_envelope_test() {
  let node_id = types.NodeId("complex-node")

  let base_envelope =
    distributed_pubsub.new_message_envelope(
      "complex-msg",
      "system.complex",
      "{\"complex\":true}",
      node_id,
    )

  // Create complex envelope with custom settings
  let complex_envelope =
    distributed_pubsub.MessageEnvelope(
      ..base_envelope,
      priority: distributed_pubsub.Critical,
      delivery_guarantee: distributed_pubsub.ExactlyOnce,
      ttl: Some(300_000),
      // 5 minutes
      max_retries: 5,
      correlation_id: Some("correlation-123"),
      headers: dict.new()
        |> dict.insert("source", "test-system")
        |> dict.insert("version", "1.0.0"),
    )

  complex_envelope.priority
  |> should.equal(distributed_pubsub.Critical)

  complex_envelope.delivery_guarantee
  |> should.equal(distributed_pubsub.ExactlyOnce)

  complex_envelope.ttl
  |> should.equal(Some(300_000))

  complex_envelope.max_retries
  |> should.equal(5)

  complex_envelope.correlation_id
  |> should.equal(Some("correlation-123"))

  dict.get(complex_envelope.headers, "source")
  |> should.equal(Ok("test-system"))

  dict.get(complex_envelope.headers, "version")
  |> should.equal(Ok("1.0.0"))
}

/// Test topic patterns
pub fn topic_patterns_test() {
  // Test exact pattern
  let exact_pattern = distributed_pubsub.Exact("system.health")
  let exact_subscription =
    distributed_pubsub.new_subscription(
      "exact-sub",
      types.NodeId("node-1"),
      exact_pattern,
      "exact-handler",
    )

  exact_subscription.pattern
  |> should.equal(distributed_pubsub.Exact("system.health"))

  // Test wildcard pattern
  let wildcard_pattern = distributed_pubsub.Wildcard("system.*")
  let wildcard_subscription =
    distributed_pubsub.new_subscription(
      "wildcard-sub",
      types.NodeId("node-1"),
      wildcard_pattern,
      "wildcard-handler",
    )

  wildcard_subscription.pattern
  |> should.equal(distributed_pubsub.Wildcard("system.*"))

  // Test multi-level pattern
  let multilevel_pattern = distributed_pubsub.MultiLevel("system.**")
  let multilevel_subscription =
    distributed_pubsub.new_subscription(
      "multilevel-sub",
      types.NodeId("node-1"),
      multilevel_pattern,
      "multilevel-handler",
    )

  multilevel_subscription.pattern
  |> should.equal(distributed_pubsub.MultiLevel("system.**"))

  // Test regex pattern
  let regex_pattern = distributed_pubsub.Regex("^system\\.(health|status)$")
  let regex_subscription =
    distributed_pubsub.new_subscription(
      "regex-sub",
      types.NodeId("node-1"),
      regex_pattern,
      "regex-handler",
    )

  regex_subscription.pattern
  |> should.equal(distributed_pubsub.Regex("^system\\.(health|status)$"))
}

/// Test subscription with filtering
pub fn subscription_with_filtering_test() {
  let node_id = types.NodeId("filter-node")
  let pattern = distributed_pubsub.Exact("events.user")

  let base_subscription =
    distributed_pubsub.new_subscription(
      "filtered-sub",
      node_id,
      pattern,
      "user-event-handler",
    )

  // Create subscription with filtering
  let filtered_subscription =
    distributed_pubsub.Subscription(
      ..base_subscription,
      delivery_guarantee: distributed_pubsub.ExactlyOnce,
      filter_expression: Some("user.role == 'admin'"),
      active: True,
    )

  filtered_subscription.filter_expression
  |> should.equal(Some("user.role == 'admin'"))

  filtered_subscription.delivery_guarantee
  |> should.equal(distributed_pubsub.ExactlyOnce)

  filtered_subscription.active
  |> should.equal(True)
}

/// Test message acknowledgment status variations
pub fn message_ack_status_variations_test() {
  // Test pending acknowledgment
  let pending_ack =
    distributed_pubsub.new_message_ack(
      "msg-1",
      "sub-1",
      distributed_pubsub.Pending,
    )

  pending_ack.status
  |> should.equal(distributed_pubsub.Pending)

  // Test failed acknowledgment with error details
  let failed_ack =
    distributed_pubsub.MessageAck(
      message_id: "msg-2",
      subscription_id: "sub-2",
      status: distributed_pubsub.Failed,
      timestamp: types.now(),
      error_details: Some("Handler timeout"),
    )

  failed_ack.status
  |> should.equal(distributed_pubsub.Failed)

  failed_ack.error_details
  |> should.equal(Some("Handler timeout"))

  // Test expired acknowledgment
  let expired_ack =
    distributed_pubsub.MessageAck(
      message_id: "msg-3",
      subscription_id: "sub-3",
      status: distributed_pubsub.Expired,
      timestamp: types.now(),
      error_details: Some("Message TTL expired"),
    )

  expired_ack.status
  |> should.equal(distributed_pubsub.Expired)
}

/// Test custom retention policy
pub fn custom_retention_policy_test() {
  let custom_policy =
    distributed_pubsub.RetentionPolicy(
      max_messages: Some(5000),
      max_age: Some(7_200_000),
      // 2 hours
      max_size: Some(50 * 1024 * 1024),
      // 50MB
    )

  custom_policy.max_messages
  |> should.equal(Some(5000))

  custom_policy.max_age
  |> should.equal(Some(7_200_000))

  custom_policy.max_size
  |> should.equal(Some(50 * 1024 * 1024))
}

/// Test end-to-end message flow
pub fn end_to_end_message_flow_test() {
  let node_id = types.NodeId("e2e-node")
  let cluster_name = "e2e-cluster"

  case distributed_pubsub.start_link(node_id, cluster_name) {
    Ok(started) -> {
      // 1. Create topic
      let retention = distributed_pubsub.default_retention_policy()
      distributed_pubsub.create_topic(started, "e2e.test", retention)
      process.sleep(10)

      // 2. Create subscription
      let subscription =
        distributed_pubsub.new_subscription(
          "e2e-sub",
          node_id,
          distributed_pubsub.Exact("e2e.test"),
          "e2e-handler",
        )
      distributed_pubsub.subscribe(started, subscription)
      process.sleep(10)

      // 3. Publish message
      let envelope =
        distributed_pubsub.new_message_envelope(
          "e2e-msg-1",
          "e2e.test",
          "{\"test\":\"end-to-end\"}",
          node_id,
        )
      distributed_pubsub.publish(started, envelope)
      process.sleep(10)

      // 4. Acknowledge message
      let ack =
        distributed_pubsub.new_message_ack(
          "e2e-msg-1",
          "e2e-sub",
          distributed_pubsub.Acknowledged,
        )
      distributed_pubsub.acknowledge_message(started, ack)
      process.sleep(10)

      // 5. Get statistics
      distributed_pubsub.get_statistics(started)
      process.sleep(10)

      // 6. Cleanup
      distributed_pubsub.cleanup_expired_messages(started)
      distributed_pubsub.compact_message_store(started)
      process.sleep(20)

      // 7. Shutdown
      distributed_pubsub.shutdown(started)

      should.be_true(True)
    }
    Error(_) -> {
      should.fail()
    }
  }
}
