/// Base agent module for defining common agent behaviors
/// Provides a foundation for creating specialized agents in the homelab system

import gleam/option.{type Option}

/// Agent configuration type
pub type AgentConfig {
  AgentConfig(
    id: String,
    name: String,
    capabilities: List(String)
  )
}

/// Agent state type
pub type AgentState {
  AgentState(
    config: AgentConfig,
    status: AgentStatus,
    metadata: Option(String)
  )
}

/// Possible agent statuses
pub type AgentStatus {
  Idle
  Active
  Paused
  Error(message: String)
}

/// Create a new agent with the given configuration
pub fn new_agent(config: AgentConfig) -> AgentState {
  AgentState(
    config: config, 
    status: Idle, 
    metadata: option.None
  )
}

/// Update agent status
pub fn update_status(state: AgentState, new_status: AgentStatus) -> AgentState {
  AgentState(..state, status: new_status)
}

/// Add a capability to the agent
pub fn add_capability(state: AgentState, capability: String) -> AgentState {
  let new_capabilities = [capability, ..state.config.capabilities]
  let new_config = AgentConfig(
    ..state.config,
    capabilities: new_capabilities
  )
  AgentState(..state, config: new_config)
}