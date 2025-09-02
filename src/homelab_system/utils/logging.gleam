/// Structured logging utility for the homelab system
/// Provides different log levels and contextual information
import gleam/io
import gleam/list
import gleam/string

/// Log levels for the homelab system
pub type LogLevel {
  Debug
  Info
  Warn
  Error
  Fatal
}

/// Log entry structure
pub type LogEntry {
  LogEntry(
    timestamp: String,
    level: LogLevel,
    message: String,
    module: String,
    context: List(#(String, String)),
  )
}

/// Logging configuration
pub type LogConfig {
  LogConfig(
    min_level: LogLevel,
    include_timestamp: Bool,
    include_module: Bool,
    format_json: Bool,
  )
}

/// Default logging configuration
pub fn default_config() -> LogConfig {
  LogConfig(
    min_level: Info,
    include_timestamp: True,
    include_module: True,
    format_json: False,
  )
}

/// Log a debug message
pub fn debug(message: String) -> Nil {
  log_with_level(Debug, message, "unknown", [])
}

/// Log a debug message with context
pub fn debug_with_context(
  message: String,
  module: String,
  context: List(#(String, String)),
) -> Nil {
  log_with_level(Debug, message, module, context)
}

/// Log an info message
pub fn info(message: String) -> Nil {
  log_with_level(Info, message, "unknown", [])
}

/// Log an info message with context
pub fn info_with_context(
  message: String,
  module: String,
  context: List(#(String, String)),
) -> Nil {
  log_with_level(Info, message, module, context)
}

/// Log a warning message
pub fn warn(message: String) -> Nil {
  log_with_level(Warn, message, "unknown", [])
}

/// Log a warning message with context
pub fn warn_with_context(
  message: String,
  module: String,
  context: List(#(String, String)),
) -> Nil {
  log_with_level(Warn, message, module, context)
}

/// Log an error message
pub fn error(message: String) -> Nil {
  log_with_level(Error, message, "unknown", [])
}

/// Log an error message with context
pub fn error_with_context(
  message: String,
  module: String,
  context: List(#(String, String)),
) -> Nil {
  log_with_level(Error, message, module, context)
}

/// Log a fatal message
pub fn fatal(message: String) -> Nil {
  log_with_level(Fatal, message, "unknown", [])
}

/// Log a fatal message with context
pub fn fatal_with_context(
  message: String,
  module: String,
  context: List(#(String, String)),
) -> Nil {
  log_with_level(Fatal, message, module, context)
}

/// Core logging function with level
fn log_with_level(
  level: LogLevel,
  message: String,
  module: String,
  context: List(#(String, String)),
) -> Nil {
  let config = default_config()

  case should_log(level, config.min_level) {
    True -> {
      let entry =
        LogEntry(
          timestamp: get_timestamp(),
          level: level,
          message: message,
          module: module,
          context: context,
        )

      let formatted = format_log_entry(entry, config)
      io.println(formatted)
    }
    False -> Nil
  }
}

/// Check if a message should be logged based on level
fn should_log(level: LogLevel, min_level: LogLevel) -> Bool {
  level_to_int(level) >= level_to_int(min_level)
}

/// Convert log level to integer for comparison
fn level_to_int(level: LogLevel) -> Int {
  case level {
    Debug -> 0
    Info -> 1
    Warn -> 2
    Error -> 3
    Fatal -> 4
  }
}

/// Convert log level to string
fn level_to_string(level: LogLevel) -> String {
  case level {
    Debug -> "DEBUG"
    Info -> "INFO"
    Warn -> "WARN"
    Error -> "ERROR"
    Fatal -> "FATAL"
  }
}

/// Format log entry according to configuration
fn format_log_entry(entry: LogEntry, config: LogConfig) -> String {
  case config.format_json {
    True -> format_as_json(entry, config)
    False -> format_as_text(entry, config)
  }
}

/// Format log entry as plain text
fn format_as_text(entry: LogEntry, config: LogConfig) -> String {
  let level_str = "[" <> level_to_string(entry.level) <> "]"
  let padded_level = pad_left_manual(level_str, 7, " ")

  let timestamp_part = case config.include_timestamp {
    True -> entry.timestamp <> " "
    False -> ""
  }

  let module_part = case config.include_module {
    True -> " (" <> entry.module <> ")"
    False -> ""
  }

  let context_part = case entry.context {
    [] -> ""
    _ -> " " <> format_context_text(entry.context)
  }

  timestamp_part
  <> padded_level
  <> " "
  <> entry.message
  <> module_part
  <> context_part
}

/// Format log entry as JSON (simplified)
fn format_as_json(entry: LogEntry, _config: LogConfig) -> String {
  let context_json = format_context_json(entry.context)

  "{"
  <> "\"timestamp\":\""
  <> entry.timestamp
  <> "\","
  <> "\"level\":\""
  <> level_to_string(entry.level)
  <> "\","
  <> "\"message\":\""
  <> entry.message
  <> "\","
  <> "\"module\":\""
  <> entry.module
  <> "\""
  <> case context_json {
    "" -> ""
    _ -> "," <> context_json
  }
  <> "}"
}

/// Format context as key=value pairs
fn format_context_text(context: List(#(String, String))) -> String {
  context
  |> list.map(fn(pair) { pair.0 <> "=" <> pair.1 })
  |> string.join(" ")
}

/// Format context as JSON fields
fn format_context_json(context: List(#(String, String))) -> String {
  case context {
    [] -> ""
    _ -> {
      context
      |> list.map(fn(pair) { "\"" <> pair.0 <> "\":\"" <> pair.1 <> "\"" })
      |> string.join(",")
    }
  }
}

/// Get current timestamp (placeholder implementation)
fn get_timestamp() -> String {
  // TODO: Implement actual timestamp using erlang time functions
  // For now, return a placeholder
  "2024-01-01T00:00:00Z"
}

/// Manually pad string to the left (replacement for string.pad_left)
fn pad_left_manual(text: String, target_length: Int, pad_char: String) -> String {
  let current_length = string.length(text)
  case current_length >= target_length {
    True -> text
    False -> {
      let padding_needed = target_length - current_length
      let padding = string.repeat(pad_char, padding_needed)
      padding <> text
    }
  }
}

/// Log system startup
pub fn log_startup(node_name: String, version: String) -> Nil {
  info_with_context("System starting up", "application", [
    #("node_name", node_name),
    #("version", version),
  ])
}

/// Log system shutdown
pub fn log_shutdown(node_name: String, uptime_seconds: String) -> Nil {
  info_with_context("System shutting down", "application", [
    #("node_name", node_name),
    #("uptime_seconds", uptime_seconds),
  ])
}

/// Log cluster events
pub fn log_cluster_event(
  event_type: String,
  details: List(#(String, String)),
) -> Nil {
  info_with_context("Cluster event: " <> event_type, "cluster", details)
}

/// Log service lifecycle events
pub fn log_service_event(
  service_name: String,
  event: String,
  status: String,
) -> Nil {
  info_with_context("Service " <> event, "supervisor", [
    #("service", service_name),
    #("status", status),
  ])
}

/// Log performance metrics
pub fn log_metrics(metric_name: String, value: String, unit: String) -> Nil {
  debug_with_context("Metric recorded", "metrics", [
    #("metric", metric_name),
    #("value", value),
    #("unit", unit),
  ])
}

/// Log agent registration
pub fn log_agent_registration(
  agent_id: String,
  agent_type: String,
  capabilities: String,
) -> Nil {
  info_with_context("Agent registered", "agent_registry", [
    #("agent_id", agent_id),
    #("type", agent_type),
    #("capabilities", capabilities),
  ])
}
