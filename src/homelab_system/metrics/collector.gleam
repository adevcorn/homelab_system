//// Homelab System Metrics Collector Module
////
//// This module provides metrics collection functionality for monitoring
//// system performance, health, and usage statistics.
////
//// Features:
//// - System resource metrics (CPU, memory, disk)
//// - Application performance metrics
//// - Custom business metrics
//// - Metrics aggregation and export
//// - Time-series data collection

import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list

import gleam/string

/// Metric value types
pub type MetricValue {
  Counter(value: Int)
  Gauge(value: Float)
  Histogram(buckets: List(#(Float, Int)), count: Int, sum: Float)
  Summary(count: Int, sum: Float, quantiles: Dict(Float, Float))
}

/// Metric metadata
pub type Metric {
  Metric(
    name: String,
    help: String,
    labels: Dict(String, String),
    value: MetricValue,
    timestamp: Int,
  )
}

/// Metrics collector state
pub type MetricsCollector {
  MetricsCollector(
    metrics: Dict(String, Metric),
    enabled: Bool,
    collection_interval: Int,
    last_collection: Int,
  )
}

/// Collection result
pub type CollectionResult {
  CollectionSuccess(collected_count: Int)
  CollectionError(message: String)
}

/// Create a new metrics collector
pub fn new() -> MetricsCollector {
  MetricsCollector(
    metrics: dict.new(),
    enabled: True,
    collection_interval: 60,
    // 60 seconds
    last_collection: 0,
  )
}

/// Start metrics collection
pub fn start(collector: MetricsCollector) -> Result(MetricsCollector, String) {
  case collector.enabled {
    True -> Ok(MetricsCollector(..collector, enabled: True))
    False -> Ok(MetricsCollector(..collector, enabled: True))
  }
}

/// Stop metrics collection
pub fn stop(collector: MetricsCollector) -> MetricsCollector {
  MetricsCollector(..collector, enabled: False)
}

/// Register a new metric
pub fn register_metric(
  collector: MetricsCollector,
  metric: Metric,
) -> MetricsCollector {
  let updated_metrics = dict.insert(collector.metrics, metric.name, metric)
  MetricsCollector(..collector, metrics: updated_metrics)
}

/// Update an existing metric value
pub fn update_metric(
  collector: MetricsCollector,
  name: String,
  value: MetricValue,
) -> MetricsCollector {
  case dict.get(collector.metrics, name) {
    Ok(existing_metric) -> {
      let updated_metric =
        Metric(
          ..existing_metric,
          value: value,
          timestamp: get_current_timestamp(),
        )
      let updated_metrics = dict.insert(collector.metrics, name, updated_metric)
      MetricsCollector(..collector, metrics: updated_metrics)
    }
    Error(_) -> collector
  }
}

/// Increment a counter metric
pub fn increment_counter(
  collector: MetricsCollector,
  name: String,
  increment: Int,
) -> MetricsCollector {
  case dict.get(collector.metrics, name) {
    Ok(metric) -> {
      case metric.value {
        Counter(current_value) -> {
          let new_value = Counter(current_value + increment)
          update_metric(collector, name, new_value)
        }
        _ -> collector
      }
    }
    Error(_) -> collector
  }
}

/// Set a gauge metric value
pub fn set_gauge(
  collector: MetricsCollector,
  name: String,
  value: Float,
) -> MetricsCollector {
  let gauge_value = Gauge(value)
  update_metric(collector, name, gauge_value)
}

/// Record a histogram observation
pub fn observe_histogram(
  collector: MetricsCollector,
  name: String,
  value: Float,
) -> MetricsCollector {
  case dict.get(collector.metrics, name) {
    Ok(metric) -> {
      case metric.value {
        Histogram(buckets, count, sum) -> {
          let new_count = count + 1
          let new_sum = sum +. value
          let updated_buckets = update_histogram_buckets(buckets, value)
          let new_value = Histogram(updated_buckets, new_count, new_sum)
          update_metric(collector, name, new_value)
        }
        _ -> collector
      }
    }
    Error(_) -> collector
  }
}

/// Update histogram buckets with new observation
fn update_histogram_buckets(
  buckets: List(#(Float, Int)),
  value: Float,
) -> List(#(Float, Int)) {
  list.map(buckets, fn(bucket) {
    let #(upper_bound, count) = bucket
    case value <=. upper_bound {
      True -> #(upper_bound, count + 1)
      False -> #(upper_bound, count)
    }
  })
}

/// Collect all system metrics
pub fn collect_system_metrics(
  collector: MetricsCollector,
) -> #(MetricsCollector, CollectionResult) {
  case collector.enabled {
    False -> #(collector, CollectionError("Metrics collection is disabled"))
    True -> {
      let updated_collector =
        collector
        |> collect_memory_metrics()
        |> collect_cpu_metrics()
        |> collect_disk_metrics()
        |> collect_network_metrics()
        |> collect_application_metrics()

      let collected_count = dict.size(updated_collector.metrics)
      let final_collector =
        MetricsCollector(
          ..updated_collector,
          last_collection: get_current_timestamp(),
        )

      #(final_collector, CollectionSuccess(collected_count))
    }
  }
}

/// Collect memory usage metrics
fn collect_memory_metrics(collector: MetricsCollector) -> MetricsCollector {
  // TODO: Implement actual memory metrics collection
  let memory_used_metric =
    Metric(
      name: "homelab_memory_used_bytes",
      help: "Memory usage in bytes",
      labels: dict.new() |> dict.insert("type", "used"),
      value: Gauge(1024.0 *. 1024.0 *. 512.0),
      // 512 MB placeholder
      timestamp: get_current_timestamp(),
    )

  let memory_total_metric =
    Metric(
      name: "homelab_memory_total_bytes",
      help: "Total memory in bytes",
      labels: dict.new() |> dict.insert("type", "total"),
      value: Gauge(1024.0 *. 1024.0 *. 1024.0 *. 8.0),
      // 8 GB placeholder
      timestamp: get_current_timestamp(),
    )

  collector
  |> register_metric(memory_used_metric)
  |> register_metric(memory_total_metric)
}

/// Collect CPU usage metrics
fn collect_cpu_metrics(collector: MetricsCollector) -> MetricsCollector {
  // TODO: Implement actual CPU metrics collection
  let cpu_usage_metric =
    Metric(
      name: "homelab_cpu_usage_percent",
      help: "CPU usage percentage",
      labels: dict.new() |> dict.insert("core", "all"),
      value: Gauge(45.5),
      // 45.5% placeholder
      timestamp: get_current_timestamp(),
    )

  register_metric(collector, cpu_usage_metric)
}

/// Collect disk usage metrics
fn collect_disk_metrics(collector: MetricsCollector) -> MetricsCollector {
  // TODO: Implement actual disk metrics collection
  let disk_used_metric =
    Metric(
      name: "homelab_disk_used_bytes",
      help: "Disk space used in bytes",
      labels: dict.new() |> dict.insert("device", "/dev/sda1"),
      value: Gauge(1024.0 *. 1024.0 *. 1024.0 *. 100.0),
      // 100 GB placeholder
      timestamp: get_current_timestamp(),
    )

  register_metric(collector, disk_used_metric)
}

/// Collect network metrics
fn collect_network_metrics(collector: MetricsCollector) -> MetricsCollector {
  // TODO: Implement actual network metrics collection
  let network_rx_metric =
    Metric(
      name: "homelab_network_rx_bytes_total",
      help: "Network bytes received",
      labels: dict.new() |> dict.insert("interface", "eth0"),
      value: Counter(1024 * 1024 * 50),
      // 50 MB placeholder
      timestamp: get_current_timestamp(),
    )

  register_metric(collector, network_rx_metric)
}

/// Collect application-specific metrics
fn collect_application_metrics(collector: MetricsCollector) -> MetricsCollector {
  let uptime_metric =
    Metric(
      name: "homelab_uptime_seconds",
      help: "System uptime in seconds",
      labels: dict.new(),
      value: Gauge(3600.0),
      // 1 hour placeholder
      timestamp: get_current_timestamp(),
    )

  let active_connections_metric =
    Metric(
      name: "homelab_active_connections",
      help: "Number of active connections",
      labels: dict.new(),
      value: Gauge(5.0),
      // 5 connections placeholder
      timestamp: get_current_timestamp(),
    )

  collector
  |> register_metric(uptime_metric)
  |> register_metric(active_connections_metric)
}

/// Get all metrics as a list
pub fn get_all_metrics(collector: MetricsCollector) -> List(Metric) {
  dict.values(collector.metrics)
}

/// Get a specific metric by name
pub fn get_metric(
  collector: MetricsCollector,
  name: String,
) -> Result(Metric, String) {
  case dict.get(collector.metrics, name) {
    Ok(metric) -> Ok(metric)
    Error(_) -> Error("Metric not found: " <> name)
  }
}

/// Export metrics in Prometheus format
pub fn export_prometheus_format(collector: MetricsCollector) -> String {
  let metrics = get_all_metrics(collector)
  let lines =
    list.map(metrics, fn(metric) { metric_to_prometheus_line(metric) })
  string.join(lines, "\n")
}

/// Convert a metric to Prometheus format line
fn metric_to_prometheus_line(metric: Metric) -> String {
  let labels_str = format_labels(metric.labels)
  let value_str = format_metric_value(metric.value)

  "# HELP "
  <> metric.name
  <> " "
  <> metric.help
  <> "\n"
  <> "# TYPE "
  <> metric.name
  <> " "
  <> get_metric_type(metric.value)
  <> "\n"
  <> metric.name
  <> labels_str
  <> " "
  <> value_str
}

/// Format labels for Prometheus output
fn format_labels(labels: Dict(String, String)) -> String {
  case dict.size(labels) {
    0 -> ""
    _ -> {
      let pairs =
        dict.to_list(labels)
        |> list.map(fn(pair) {
          let #(key, value) = pair
          key <> "=\"" <> value <> "\""
        })
      "{" <> string.join(pairs, ",") <> "}"
    }
  }
}

/// Format metric value for output
fn format_metric_value(value: MetricValue) -> String {
  case value {
    Counter(v) -> int.to_string(v)
    Gauge(v) -> float.to_string(v)
    Histogram(_buckets, count, sum) ->
      "count=" <> int.to_string(count) <> " sum=" <> float.to_string(sum)
    Summary(count, sum, _quantiles) ->
      "count=" <> int.to_string(count) <> " sum=" <> float.to_string(sum)
  }
}

/// Get metric type string for Prometheus
fn get_metric_type(value: MetricValue) -> String {
  case value {
    Counter(_) -> "counter"
    Gauge(_) -> "gauge"
    Histogram(_, _, _) -> "histogram"
    Summary(_, _, _) -> "summary"
  }
}

/// Get current timestamp (placeholder implementation)
fn get_current_timestamp() -> Int {
  // TODO: Implement actual timestamp generation
  1_704_067_200
  // 2024-01-01 00:00:00 UTC
}

/// Check if metrics collection is enabled
pub fn is_enabled(collector: MetricsCollector) -> Bool {
  collector.enabled
}

/// Get collection statistics
pub fn get_stats(collector: MetricsCollector) -> Dict(String, String) {
  dict.new()
  |> dict.insert("enabled", case collector.enabled {
    True -> "true"
    False -> "false"
  })
  |> dict.insert("metric_count", int.to_string(dict.size(collector.metrics)))
  |> dict.insert("last_collection", int.to_string(collector.last_collection))
  |> dict.insert(
    "collection_interval",
    int.to_string(collector.collection_interval),
  )
}
