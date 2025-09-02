//// Configuration Validation Test Module
////
//// Comprehensive test suite for the validation module using gleeunit.

import gleam/dict
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleeunit
import gleeunit/should

import homelab_system/config/cluster_config
import homelab_system/config/node_config
import homelab_system/config/validation.{
  type ValidationContext, type ValidationIssue, type ValidationSeverity,
  SeverityError, SeverityInfo, SeverityWarning, ValidationContext,
  ValidationIssue,
}

pub fn main() {
  gleeunit.main()
}

// Test validation context creation
pub fn default_validation_context_test() {
  let context = validation.default_validation_context()

  context.environment |> should.equal("development")
  context.strict_mode |> should.equal(False)
  context.allow_warnings |> should.equal(True)
}

pub fn strict_validation_context_test() {
  let context = validation.strict_validation_context()

  context.environment |> should.equal("production")
  context.strict_mode |> should.equal(True)
  context.allow_warnings |> should.equal(False)
}

// Test node configuration validation
pub fn validate_node_config_valid_test() {
  let config = node_config.default_config()
  let context = validation.default_validation_context()

  case validation.validate_node_config(config, context) {
    Ok(issues) -> {
      // Default config should have minimal issues
      let errors = validation.filter_by_severity(issues, SeverityError)
      list.length(errors) |> should.equal(0)
    }
    Error(_) -> should.fail()
  }
}

pub fn validate_node_config_empty_id_test() {
  let config =
    node_config.NodeConfig(..node_config.default_config(), node_id: "")
  let context = validation.default_validation_context()

  case validation.validate_node_config(config, context) {
    Ok(issues) -> {
      let errors = validation.filter_by_severity(issues, SeverityError)
      should.be_true(list.length(errors) > 0)

      let error_messages = validation.issues_to_strings(errors)
      should.be_true(
        list.any(error_messages, fn(msg) {
          string.contains(msg, "Node ID cannot be empty")
        }),
      )
    }
    Error(_) -> should.fail()
  }
}

pub fn validate_node_config_invalid_port_test() {
  let config =
    node_config.NodeConfig(
      ..node_config.default_config(),
      network: node_config.NetworkConfig(
        ..node_config.default_config().network,
        port: 0,
      ),
    )
  let context = validation.default_validation_context()

  case validation.validate_node_config(config, context) {
    Ok(issues) -> {
      let errors = validation.filter_by_severity(issues, SeverityError)
      should.be_true(list.length(errors) > 0)

      let error_messages = validation.issues_to_strings(errors)
      should.be_true(
        list.any(error_messages, fn(msg) {
          string.contains(msg, "Port must be between 1 and 65535")
        }),
      )
    }
    Error(_) -> should.fail()
  }
}

pub fn validate_node_config_invalid_memory_test() {
  let config =
    node_config.NodeConfig(
      ..node_config.default_config(),
      resources: node_config.ResourceConfig(
        ..node_config.default_config().resources,
        max_memory_mb: -100,
      ),
    )
  let context = validation.default_validation_context()

  case validation.validate_node_config(config, context) {
    Ok(issues) -> {
      let errors = validation.filter_by_severity(issues, SeverityError)
      should.be_true(list.length(errors) > 0)

      let error_messages = validation.issues_to_strings(errors)
      should.be_true(
        list.any(error_messages, fn(msg) {
          string.contains(msg, "Max memory must be positive")
        }),
      )
    }
    Error(_) -> should.fail()
  }
}

// Test cluster configuration validation
pub fn validate_cluster_config_valid_test() {
  let config = cluster_config.default_config()
  let context = validation.default_validation_context()

  case validation.validate_cluster_config(config, context) {
    Ok(issues) -> {
      // Default config should have minimal issues
      let errors = validation.filter_by_severity(issues, SeverityError)
      list.length(errors) |> should.equal(0)
    }
    Error(_) -> should.fail()
  }
}

pub fn validate_cluster_config_empty_id_test() {
  let config =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      cluster_id: "",
    )
  let context = validation.default_validation_context()

  case validation.validate_cluster_config(config, context) {
    Ok(issues) -> {
      let errors = validation.filter_by_severity(issues, SeverityError)
      should.be_true(list.length(errors) > 0)

      let error_messages = validation.issues_to_strings(errors)
      should.be_true(
        list.any(error_messages, fn(msg) {
          string.contains(msg, "Cluster ID cannot be empty")
        }),
      )
    }
    Error(_) -> should.fail()
  }
}

pub fn validate_cluster_config_invalid_port_range_test() {
  let config =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      networking: cluster_config.ClusterNetworkConfig(
        ..cluster_config.default_config().networking,
        cluster_port_range_start: 6000,
        cluster_port_range_end: 5000,
      ),
    )
  let context = validation.default_validation_context()

  case validation.validate_cluster_config(config, context) {
    Ok(issues) -> {
      let errors = validation.filter_by_severity(issues, SeverityError)
      should.be_true(list.length(errors) > 0)

      let error_messages = validation.issues_to_strings(errors)
      should.be_true(
        list.any(error_messages, fn(msg) {
          string.contains(msg, "Port range end must be greater than start")
        }),
      )
    }
    Error(_) -> should.fail()
  }
}

// Test consistency validation
pub fn validate_configs_consistency_valid_test() {
  let node_config = node_config.default_config()
  let cluster_config = cluster_config.default_config()
  let context = validation.default_validation_context()

  case
    validation.validate_configs_consistency(
      node_config,
      cluster_config,
      context,
    )
  {
    Ok(issues) -> {
      // Default configs should have minimal consistency issues
      let errors = validation.filter_by_severity(issues, SeverityError)
      list.length(errors) |> should.equal(0)
    }
    Error(_) -> should.fail()
  }
}

pub fn validate_configs_port_conflict_test() {
  let node_config =
    node_config.NodeConfig(
      ..node_config.default_config(),
      network: node_config.NetworkConfig(
        ..node_config.default_config().network,
        port: 4001,
        // Same as discovery port
      ),
    )
  let cluster_config = cluster_config.default_config()
  let context = validation.default_validation_context()

  case
    validation.validate_configs_consistency(
      node_config,
      cluster_config,
      context,
    )
  {
    Ok(issues) -> {
      let errors = validation.filter_by_severity(issues, SeverityError)
      should.be_true(list.length(errors) > 0)

      let error_messages = validation.issues_to_strings(errors)
      should.be_true(
        list.any(error_messages, fn(msg) {
          string.contains(
            msg,
            "Node port conflicts with cluster discovery port",
          )
        }),
      )
    }
    Error(_) -> should.fail()
  }
}

pub fn validate_configs_environment_mismatch_test() {
  let node_config =
    node_config.NodeConfig(
      ..node_config.default_config(),
      environment: "production",
    )
  let cluster_config =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      environment: "development",
    )
  let context = validation.default_validation_context()

  case
    validation.validate_configs_consistency(
      node_config,
      cluster_config,
      context,
    )
  {
    Ok(issues) -> {
      let warnings = validation.filter_by_severity(issues, SeverityWarning)
      should.be_true(list.length(warnings) > 0)

      let warning_messages = validation.issues_to_strings(warnings)
      should.be_true(
        list.any(warning_messages, fn(msg) {
          string.contains(msg, "Node and cluster environments don't match")
        }),
      )
    }
    Error(_) -> should.fail()
  }
}

// Test validation issue filtering and utilities
pub fn has_errors_test() {
  let issues = [
    ValidationIssue(SeverityError, "test", "Test error", "value", None),
    ValidationIssue(SeverityWarning, "test2", "Test warning", "value", None),
  ]

  validation.has_errors(issues) |> should.equal(True)
}

pub fn has_warnings_test() {
  let issues = [
    ValidationIssue(SeverityInfo, "test", "Test info", "value", None),
    ValidationIssue(SeverityWarning, "test2", "Test warning", "value", None),
  ]

  validation.has_warnings(issues) |> should.equal(True)
}

pub fn filter_by_severity_test() {
  let issues = [
    ValidationIssue(SeverityError, "test1", "Test error", "value", None),
    ValidationIssue(SeverityWarning, "test2", "Test warning", "value", None),
    ValidationIssue(SeverityInfo, "test3", "Test info", "value", None),
  ]

  let errors = validation.filter_by_severity(issues, SeverityError)
  list.length(errors) |> should.equal(1)

  let warnings = validation.filter_by_severity(issues, SeverityWarning)
  list.length(warnings) |> should.equal(1)

  let infos = validation.filter_by_severity(issues, SeverityInfo)
  list.length(infos) |> should.equal(1)
}

pub fn issues_to_strings_test() {
  let issues = [
    ValidationIssue(
      SeverityError,
      "test_field",
      "Test error message",
      "bad_value",
      None,
    ),
    ValidationIssue(
      SeverityWarning,
      "other_field",
      "Test warning",
      "ok_value",
      Some("better_value"),
    ),
  ]

  let strings = validation.issues_to_strings(issues)
  list.length(strings) |> should.equal(2)

  should.be_true(
    list.any(strings, fn(s) {
      string.contains(s, "[ERROR] test_field: Test error message")
    }),
  )

  should.be_true(
    list.any(strings, fn(s) {
      string.contains(s, "[WARNING] other_field: Test warning")
    }),
  )
}

pub fn format_validation_report_empty_test() {
  let report = validation.format_validation_report([])
  should.be_true(string.contains(report, "no issues"))
}

pub fn format_validation_report_with_issues_test() {
  let issues = [
    ValidationIssue(SeverityError, "test_field", "Test error", "value", None),
    ValidationIssue(
      SeverityWarning,
      "warn_field",
      "Test warning",
      "value",
      None,
    ),
  ]

  let report = validation.format_validation_report(issues)
  should.be_true(string.contains(report, "Configuration Validation Report"))
  should.be_true(string.contains(report, "Errors: 1"))
  should.be_true(string.contains(report, "Warnings: 1"))
  should.be_true(string.contains(report, "test_field"))
  should.be_true(string.contains(report, "warn_field"))
}

// Test production environment validation
pub fn production_validation_stricter_test() {
  let config =
    node_config.NodeConfig(
      ..node_config.default_config(),
      network: node_config.NetworkConfig(
        ..node_config.default_config().network,
        tls_enabled: False,
      ),
    )

  let dev_context = validation.default_validation_context()
  let prod_context = validation.strict_validation_context()

  case validation.validate_node_config(config, dev_context) {
    Ok(dev_issues) -> {
      case validation.validate_node_config(config, prod_context) {
        Ok(prod_issues) -> {
          let dev_warnings =
            validation.filter_by_severity(dev_issues, SeverityWarning)
          let prod_warnings =
            validation.filter_by_severity(prod_issues, SeverityWarning)

          // Production should have more warnings about security
          should.be_true(
            list.length(prod_warnings) >= list.length(dev_warnings),
          )
        }
        Error(_) -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}

// Test default value application
pub fn apply_node_defaults_empty_id_test() {
  let config =
    node_config.NodeConfig(..node_config.default_config(), node_id: "")
  let context = validation.default_validation_context()

  let fixed_config = validation.apply_node_defaults(config, context)
  should.be_true(fixed_config.node_id != "")
  should.be_true(string.contains(fixed_config.node_id, "development"))
}

pub fn apply_cluster_defaults_empty_id_test() {
  let config =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      cluster_id: "",
    )
  let context = validation.default_validation_context()

  let fixed_config = validation.apply_cluster_defaults(config, context)
  should.be_true(fixed_config.cluster_id != "")
  should.be_true(string.contains(fixed_config.cluster_id, "development"))
}

// Test validate and fix functions
pub fn validate_and_fix_node_config_success_test() {
  let config =
    node_config.NodeConfig(
      ..node_config.default_config(),
      node_id: "",
      // This will be fixed by defaults
      node_name: "",
    )
  let context = validation.default_validation_context()

  case validation.validate_and_fix_node_config(config, context) {
    Ok(fixed_config) -> {
      should.be_true(fixed_config.node_id != "")
      should.be_true(fixed_config.node_name != "")
    }
    Error(_) -> should.fail()
  }
}

pub fn validate_and_fix_node_config_failure_test() {
  let config =
    node_config.NodeConfig(
      ..node_config.default_config(),
      network: node_config.NetworkConfig(
        ..node_config.default_config().network,
        port: -1,
        // This cannot be fixed automatically
      ),
    )
  let context = validation.default_validation_context()

  case validation.validate_and_fix_node_config(config, context) {
    Ok(_) -> should.fail()
    Error(issues) -> {
      should.be_true(validation.has_errors(issues))
    }
  }
}

pub fn validate_and_fix_cluster_config_success_test() {
  let config =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      cluster_id: "",
      // This will be fixed by defaults
      cluster_name: "",
    )
  let context = validation.default_validation_context()

  case validation.validate_and_fix_cluster_config(config, context) {
    Ok(fixed_config) -> {
      should.be_true(fixed_config.cluster_id != "")
      should.be_true(fixed_config.cluster_name != "")
    }
    Error(_) -> should.fail()
  }
}

// Test edge cases and complex scenarios
pub fn validate_complex_node_config_test() {
  let config =
    node_config.NodeConfig(
      ..node_config.default_config(),
      node_id: "test-node-with-very-long-name-that-exceeds-normal-limits-and-should-fail",
      capabilities: ["invalid_capability", "health_check"],
      network: node_config.NetworkConfig(
        ..node_config.default_config().network,
        port: 70_000,
        // Invalid port
        max_connections: -10,
        // Invalid value
      ),
      resources: node_config.ResourceConfig(
        ..node_config.default_config().resources,
        max_cpu_percent: 150,
        // Invalid percentage
      ),
    )
  let context = validation.strict_validation_context()

  case validation.validate_node_config(config, context) {
    Ok(issues) -> {
      let errors = validation.filter_by_severity(issues, SeverityError)
      // Should have multiple errors
      should.be_true(list.length(errors) > 3)

      let error_messages = validation.issues_to_strings(errors)
      should.be_true(
        list.any(error_messages, fn(msg) {
          string.contains(msg, "exceed 64 characters")
          || string.contains(msg, "Port must be between")
        }),
      )
    }
    Error(_) -> should.fail()
  }
}

pub fn validate_complex_cluster_config_test() {
  let config =
    cluster_config.ClusterConfig(
      ..cluster_config.default_config(),
      discovery: cluster_config.DiscoveryConfig(
        ..cluster_config.default_config().discovery,
        bootstrap_nodes: ["invalid-node", "localhost:abc", "127.0.0.1:4001"],
        heartbeat_interval_ms: -1000,
      ),
      networking: cluster_config.ClusterNetworkConfig(
        ..cluster_config.default_config().networking,
        allowed_networks: ["invalid-cidr", "192.168.1.0/24", "not-a-network"],
      ),
      limits: cluster_config.ClusterLimits(
        ..cluster_config.default_config().limits,
        max_nodes: 0,
        connection_pool_size: -5,
      ),
    )
  let context = validation.strict_validation_context()

  case validation.validate_cluster_config(config, context) {
    Ok(issues) -> {
      let errors = validation.filter_by_severity(issues, SeverityError)
      // Should have multiple errors
      should.be_true(list.length(errors) > 3)
    }
    Error(_) -> should.fail()
  }
}
