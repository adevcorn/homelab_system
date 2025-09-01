/// Distributed tracing module for generating and managing correlation IDs
/// Enables tracking of distributed flows across different nodes and services

import youid/uuid
import gleam/option.{type Option}

/// Correlation ID type for tracking distributed transactions
pub type CorrelationId =
  String

/// Tracing context containing correlation and span information
pub type TracingContext {
  TracingContext(
    correlation_id: CorrelationId,
    parent_span: Option(CorrelationId),
    trace_flags: List(String)
  )
}

/// Generate a new unique correlation ID
pub fn generate_correlation_id() -> CorrelationId {
  uuid.v4_string()
}

/// Create a new tracing context with a generated correlation ID
pub fn new_context() -> TracingContext {
  TracingContext(
    correlation_id: generate_correlation_id(),
    parent_span: option.None,
    trace_flags: []
  )
}

/// Create a child span from an existing context
pub fn create_child_span(parent: TracingContext) -> TracingContext {
  TracingContext(
    correlation_id: generate_correlation_id(),
    parent_span: option.Some(parent.correlation_id),
    trace_flags: parent.trace_flags
  )
}

/// Add a trace flag to the context
pub fn add_trace_flag(context: TracingContext, flag: String) -> TracingContext {
  TracingContext(
    ..context,
    trace_flags: [flag, ..context.trace_flags]
  )
}