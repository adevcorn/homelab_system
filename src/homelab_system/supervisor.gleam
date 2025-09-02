/// Main supervision tree for the homelab system
/// Using correct gleam/otp/static_supervisor API
import gleam/erlang/process
import gleam/otp/actor
import gleam/otp/static_supervisor.{type Supervisor} as supervisor
import gleam/otp/supervision
import homelab_system/agent/base_agent
import homelab_system/config/node_config.{type NodeConfig}

/// Initialize the main supervision tree for the homelab system
/// Takes a NodeConfig to determine which services to start based on node role
pub fn start_link(
  config: NodeConfig,
) -> Result(actor.Started(Supervisor), actor.StartError) {
  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(create_agent_child_spec(config))
  |> supervisor.start
}

/// Create a supervised child spec for the base agent
fn create_agent_child_spec(
  config: NodeConfig,
) -> supervision.ChildSpecification(process.Subject(base_agent.AgentMessage)) {
  supervision.worker(fn() { base_agent.start_link(config) })
}

/// Create a supervised version of this supervisor for use in larger supervision trees
pub fn supervised(
  config: NodeConfig,
) -> supervision.ChildSpecification(Supervisor) {
  supervisor.new(supervisor.OneForOne)
  |> supervisor.add(create_agent_child_spec(config))
  |> supervisor.supervised
}

/// Get the supervision tree status
pub fn get_status() -> Result(String, String) {
  // TODO: Implement status retrieval
  Ok("Supervisor running")
}

/// Gracefully shutdown the supervision tree
pub fn shutdown() -> Result(Nil, String) {
  // TODO: Implement graceful shutdown
  Ok(Nil)
}

/// Restart a specific child service by ID
pub fn restart_child(_child_id: String) -> Result(Nil, String) {
  // TODO: Implement child restart
  Ok(Nil)
}
