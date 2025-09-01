# Homelab System - Distributed OTP Architecture Plan

## 🎯 Vision
Transform the homelab system into a distributed OTP/agent model using maximum Gleam code, enabling simple `gleam run` cluster joining and self-healing distributed operations.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Homelab Cluster                          │
├─────────────────────────────────────────────────────────────┤
│  Coordinator Nodes (glyn registry + barnacle clustering)    │
│  ├── Service Registry & Discovery                           │
│  ├── Node Health Monitoring                                 │
│  └── Task Distribution                                       │
├─────────────────────────────────────────────────────────────┤
│  Agent Nodes (specialized workers)                          │
│  ├── Server Monitoring Agents                               │
│  ├── Configuration Management Agents                        │
│  ├── Health Check Agents                                    │
│  └── Alert Processing Agents                                │
├─────────────────────────────────────────────────────────────┤
│  Gateway Nodes (external interfaces)                        │
│  ├── HTTP API Endpoints (wisp/mist)                         │
│  ├── Web Dashboard (lustre)                                 │
│  └── CLI Interface                                           │
└─────────────────────────────────────────────────────────────┘
```

## 📦 Key Gleam Packages

### Core OTP & Actors
- **`gleam_otp`** v1.1.0 - Full OTP supervisor trees, actors, and fault tolerance
- **`glyn`** v2.0.3 - Type-safe PubSub and Registry with distributed clustering support! 🎯
- **`singularity`** v1.2.0 - Singleton OTP actor registry 
- **`working_actors`** v1.1.0 - Parallel worker spawning
- **`lifeguard`** v4.0.0 - Actor pool management

### Clustering & Distribution
- **`barnacle`** v2.0.1 - Self-healing clusters for Gleam applications! 🎯
- **`taskle`** v2.0.0 - Concurrent programming with Elixir-like Task functionality
- **`ranger`** v1.4.0 - Create ranges and iterators

### Service Discovery & Communication
- **`glubsub`** v1.2.0 - Simple PubSub using Gleam actors
- **`chip`** v1.1.1 - Gleam registry library
- **`global_value`** v1.0.0 - Singleton values accessible anywhere

### Configuration & Environment
- **`glenvy`** v2.0.1 - Pleasant environment variable handling
- **`dotenv_gleam`** v2.0.0 - Environment file loading
- **`gleam_json`** v3.0.0 - JSON configuration handling (simpler than YAML/TOML initially)
- **`yodel`** v1.0.1 - Type-safe configuration loader (JSON, YAML, TOML) - *Phase 2+*

### Additional Utilities
- **`glint`** v1.2.1 - Command-line argument parsing
- **`wisp`** v2.0.0-rc1 - Web framework for API endpoints
- **`lustre`** v5.3.4 - Frontend framework for dashboards

## 🚀 Implementation Phases

### Phase 1: Core OTP Structure
**Goal**: Establish basic supervision trees and actor framework

**Priority**: Start immediately - provides value even without clustering

**Tasks**:
- [ ] Add core OTP dependencies to `gleam.toml`
- [ ] Create main supervisor tree using `gleam_otp`
- [ ] Implement basic agent framework with `singularity`
- [ ] Add configuration management with `gleam_json` + `glenvy` (simpler than `yodel` initially)
- [ ] Create command-line interface with `glint`
- [ ] Add distributed tracing IDs for debugging distributed flows

**Key Modules**:
```
src/homelab_system/
├── supervisor.gleam           # Main supervision tree
├── agent/
│   ├── agent.gleam           # Base agent behavior
│   └── supervisor.gleam      # Agent supervision
├── config/
│   ├── node_config.gleam     # Node configuration (JSON-based)
│   └── cluster_config.gleam  # Cluster settings
└── tracing/
    └── correlation.gleam     # Distributed tracing IDs
```

### Phase 2: Clustering Foundation
**Goal**: Enable distributed clustering and node discovery

**Prerequisites**: Complete Phase 1 OTP foundation first

**Tasks**:
- [ ] Integrate `barnacle` for self-healing clusters
- [ ] Implement `glyn` for distributed PubSub/Registry
- [ ] Add `glubsub` for internal messaging
- [ ] Create node discovery mechanism
- [ ] Implement cluster joining/leaving protocols
- [ ] Add integration testing framework for distributed scenarios

**Key Modules**:
```
src/homelab_system/
├── cluster/
│   ├── node_manager.gleam    # Node lifecycle management
│   ├── discovery.gleam       # Service discovery
│   └── health.gleam          # Cluster health monitoring
├── messaging/
│   ├── pubsub.gleam          # PubSub messaging
│   └── registry.gleam        # Service registry
└── testing/
    └── cluster_test.gleam    # Integration testing for distributed scenarios
```

### Phase 3: Service Architecture
**Goal**: Implement specialized agents and service distribution with domain support

**Tasks**:
- [ ] Create monitoring agent specialization
- [ ] Implement configuration management agents
- [ ] Add health check agent system
- [ ] Build alert processing pipeline
- [ ] Add load balancing with `lifeguard`
- [ ] Develop initial domain integration framework
- [ ] Create first example domain (network monitoring)

**Key Modules**:
```
src/homelab_system/
├── agents/
│   ├── monitoring/
│   │   ├── server_monitor.gleam
│   │   └── metrics_collector.gleam
│   ├── config/
│   │   ├── config_manager.gleam
│   │   └── config_sync.gleam
│   ├── health/
│   │   ├── health_checker.gleam
│   │   └── status_reporter.gleam
│   └── alerts/
│       ├── alert_processor.gleam
│       └── notification_sender.gleam
├── services/
│   ├── load_balancer.gleam
│   └── task_dispatcher.gleam
└── domains/
    └── domain_manager.gleam  # Central domain registration and management
```

### Phase 4: Gateway & Interface
**Goal**: External interfaces and user interaction

**Tasks**:
- [ ] Implement HTTP API with `wisp`
- [ ] Create web dashboard with `lustre`
- [ ] Add CLI management interface
- [ ] Implement metrics and monitoring endpoints
- [ ] Create deployment automation

**Key Modules**:
```
src/homelab_system/
├── gateway/
│   ├── http_api.gleam        # REST API endpoints
│   ├── websocket.gleam       # Real-time updates
│   └── dashboard.gleam       # Web interface
├── cli/
│   ├── commands.gleam        # CLI commands
│   └── admin.gleam           # Administrative tools
└── metrics/
    ├── collector.gleam       # Metrics collection
    └── exporter.gleam        # Metrics export
```

## 🔧 Key Features

### Pure Gleam Benefits
- **Type safety** across the entire distributed system
- **Consistent error handling** patterns throughout
- **Zero FFI dependencies** for core functionality
- **Full leverage** of BEAM's actor model and OTP principles

### Self-Healing Cluster
- `barnacle` provides automatic node recovery and fault tolerance
- `glyn` handles distributed state synchronization seamlessly
- Graceful degradation when nodes leave the cluster
- Automatic workload redistribution

### Simple Deployment
```bash
# Start coordinator node
gleam run -- --role=coordinator --cluster=homelab --port=4000

# Join as monitoring agent
gleam run -- --role=monitoring --join=coordinator@hostname:4000

# Join as configuration agent
gleam run -- --role=config --join=coordinator@hostname:4000

# Auto-discover role and join
gleam run -- --discover=homelab --auto-role

# Join with specific capabilities
gleam run -- --role=agent --capabilities=monitoring,health,alerts
```

### Node Types & Roles

#### Coordinator Nodes
- **Responsibilities**: Service registry, task distribution, cluster coordination
- **Capabilities**: Central orchestration, health monitoring, load balancing
- **Scaling**: Multiple coordinators with leader election
- **Domain Management**: Facilitate domain registration and discovery

#### Agent Nodes
- **Monitoring Agents**: Server metrics, resource monitoring, performance tracking
- **Config Agents**: Configuration management, synchronization, validation
- **Health Agents**: Health checks, status reporting, failure detection
- **Alert Agents**: Alert processing, notification routing, escalation
- **Domain-Specific Agents**: Specialized workers for custom domains

#### Gateway Nodes
- **API Gateways**: HTTP/REST endpoints, authentication, rate limiting
- **Dashboard Nodes**: Web interface, real-time monitoring, administrative tools
- **CLI Nodes**: Command-line management, scripting interfaces
- **Domain Interfaces**: Expose domain-specific APIs and interactions

## 🛠️ Dependencies Configuration

Add to `gleam.toml`:
```toml
[dependencies]
gleam_stdlib = ">= 0.44.0 and < 2.0.0"
gleam_otp = "~> 1.1"
gleam_erlang = "~> 1.3"

# Distributed clustering
glyn = "~> 2.0"           # 🎯 Distributed PubSub/Registry
barnacle = "~> 2.0"       # 🎯 Self-healing clusters
singularity = "~> 1.2"    # Singleton registry
working_actors = "~> 1.1" # Parallel workers
lifeguard = "~> 4.0"      # Actor pools

# Messaging & Communication
glubsub = "~> 1.2"        # PubSub messaging
chip = "~> 1.1"           # Service registry

# Configuration & Environment
glenvy = "~> 2.0"         # Environment variables
gleam_json = "~> 3.0"     # JSON configuration (Phase 1)
dotenv_gleam = "~> 2.0"   # .env file support
yodel = "~> 1.0"          # Advanced config loading (Phase 2+)

# CLI & Web Interface
glint = "~> 1.2"          # Command-line parsing
wisp = "~> 2.0"           # Web framework
lustre = "~> 5.3"         # Frontend framework

# Utilities
youid = "~> 1.5"          # UUID generation
gleam_json = "~> 3.0"     # JSON handling
```

## 🎮 Usage Examples

### Starting a Homelab Cluster
```bash
# Terminal 1: Start coordinator
gleam run -- --role=coordinator --cluster-name=homelab --bind=0.0.0.0:4000

# Terminal 2: Add monitoring agent
gleam run -- --role=monitoring --join=127.0.0.1:4000

# Terminal 3: Add configuration agent  
gleam run -- --role=config --join=127.0.0.1:4000

# Terminal 4: Add gateway with dashboard
gleam run -- --role=gateway --join=127.0.0.1:4000 --enable-dashboard
```

### Scaling the Cluster
```bash
# Add more monitoring agents
for i in {1..3}; do
  gleam run -- --role=monitoring --join=coordinator@homelab:4000 &
done

# Add specialized health checkers
gleam run -- --role=health --capabilities=docker,systemd,network --join=coordinator@homelab:4000
```

### Administrative Commands
```bash
# View cluster status
gleam run -- --admin cluster status

# List all nodes and their roles
gleam run -- --admin nodes list

# Restart specific service
gleam run -- --admin service restart monitoring

# View system metrics
gleam run -- --admin metrics --format=json
```

## 🔍 Monitoring & Observability

### Built-in Metrics
- **Node Health**: CPU, memory, disk, network usage per node
- **Cluster Health**: Node count, leader status, partition detection
- **Agent Performance**: Task completion rates, error rates, response times
- **Service Metrics**: Request counts, latency distributions, error rates
- **Distributed Tracing**: Correlation IDs for debugging distributed flows

### Dashboard Features
- **Real-time Cluster Topology**: Visual representation of nodes and connections
- **Service Status Grid**: Health status of all services across nodes
- **Metrics Visualization**: Time-series graphs of system and application metrics
- **Alert Management**: Current alerts, acknowledgments, escalation status

### Integration Points
- **Prometheus Export**: Native metrics export for external monitoring
- **Webhook Notifications**: Alert delivery to external systems
- **Log Aggregation**: Structured logging with correlation IDs
- **Health Check Endpoints**: HTTP endpoints for external health monitoring

## 🚀 Getting Started

### Recommended Implementation Order

1. **Phase 1 First** - Implement core OTP structure for immediate value
   - Single-node operation provides benefits before clustering complexity
   - Solid foundation enables natural scaling to distributed architecture
   
2. **Test Early** - Add integration testing framework during Phase 2
   - Use `gleeunit` with test cluster scenarios
   - Validate distributed behavior before production deployment

3. **Configuration Strategy** - Start simple, evolve complexity
   - Phase 1: `gleam_json` + environment variables
   - Phase 2+: Migrate to `yodel` for advanced configuration needs

4. **Observability from Start** - Include tracing IDs in Phase 1
   - Enables debugging distributed flows from the beginning
   - Easier to add early than retrofit later

### Implementation Steps
1. **Review current project structure** and update dependencies
2. **Implement Phase 1** - Core OTP structure and basic agents (START HERE)
3. **Add Phase 2** - Clustering with `barnacle` and `glyn`
4. **Build Phase 3** - Specialized agent implementations
5. **Deploy Phase 4** - Gateway and management interfaces

## 📝 Notes

- **Maximum Gleam**: This architecture uses pure Gleam packages wherever possible
- **BEAM Native**: Leverages full power of BEAM VM and OTP principles
- **Self-Healing**: Built-in fault tolerance and automatic recovery
- **Type Safe**: End-to-end type safety across distributed boundaries
- **Scalable**: Horizontal scaling through simple node addition
- **Observable**: Comprehensive monitoring and alerting built-in
- **Incremental Value**: Phase 1 provides immediate benefits without clustering complexity
- **Testing Strategy**: Integration testing framework ensures distributed reliability
- **Configuration Evolution**: Start simple with JSON, evolve to advanced config as needed

This architecture transforms your homelab system into a robust, distributed, fault-tolerant system while maintaining the simplicity of `gleam run` for deployment and management. The phased approach ensures you get value immediately while building toward full distributed capabilities.

## 🌐 Domain Expansion: Adding New Capabilities

### Domain Integration Philosophy
The architecture is designed to make adding new domains seamless and consistent. Each new domain follows a standardized pattern that integrates with the existing distributed system.

### Domain Structure Template
```
src/homelab_system/
└── domains/
    ├── <domain_name>/
    │   ├── agent.gleam           # Domain-specific agent behavior
    │   ├── config.gleam          # Domain configuration
    │   ├── supervisor.gleam      # Domain agent supervision
    │   ├── models.gleam          # Domain data models
    │   ├── services/
    │   │   ├── primary_service.gleam
    │   │   └── secondary_service.gleam
    │   └── events.gleam          # Domain-specific event definitions
    └── registry.gleam            # Domain registration with cluster
```

### Example: Adding a Network Monitoring Domain

#### 1. Create Domain Structure
```bash
mkdir -p src/homelab_system/domains/network/{services,models}
```

#### 2. Implement Core Components
```gleam
// src/homelab_system/domains/network/agent.gleam
pub type NetworkAgent {
  NetworkAgent(
    scan_interval: Int,
    target_networks: List(String)
  )
}

// src/homelab_system/domains/network/services/scanner.gleam
pub fn scan_network(network: String) -> Result(NetworkStatus, ScanError) {
  // Implement network scanning logic
}
```

#### 3. Register with Cluster
```gleam
// src/homelab_system/domains/network/registry.gleam
pub fn register_network_domain(cluster: Cluster) {
  cluster
  |> register_agent_type("network_monitoring")
  |> add_capabilities(["network_scan", "device_discovery"])
}
```

### Domain Integration Patterns

#### Agent Lifecycle
- Each domain defines its own agent type
- Agents can be dynamically added/removed from the cluster
- Supports specialized roles and capabilities

#### Configuration Management
- Domain-specific configuration via `config.gleam`
- Supports JSON/environment variable configuration
- Can be updated dynamically without cluster restart

#### Event-Driven Communication
- Domains communicate via `glubsub` message passing
- Define clear event contracts in `events.gleam`
- Support for cross-domain event handling

#### Scalability Considerations
- Domains can be added without modifying core system
- Each domain can have multiple agent instances
- Load balancing and task distribution handled by cluster manager

### Best Practices for Domain Addition

1. **Minimal Dependencies**
   - Keep domain logic self-contained
   - Minimize cross-domain coupling
   - Use message passing for inter-domain communication

2. **Consistent Interfaces**
   - Follow established agent and service patterns
   - Implement standard health check methods
   - Provide clear capability definitions

3. **Configuration Flexibility**
   - Support environment-based configuration
   - Allow runtime configuration updates
   - Provide sensible defaults

4. **Observability**
   - Include metrics and tracing for new domains
   - Log events with correlation IDs
   - Support Prometheus metrics export

### Future Domain Ideas
- **IoT Device Management**
- **Home Automation**
- **Security Monitoring**
- **Resource Provisioning**
- **Backup and Disaster Recovery**

By following these patterns, you can continuously expand the homelab system's capabilities while maintaining a clean, scalable, and type-safe architecture.