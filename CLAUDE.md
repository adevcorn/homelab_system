# Homelab System - AI Agent Context

## Project Overview
- **Language**: Gleam (functional language for the BEAM VM)
- **Purpose**: Homelab system management and automation
- **Architecture**: Single Gleam application with potential for distributed components

## Development Commands

### Core Commands
```bash
gleam run          # Run the main application
gleam test         # Run all tests
gleam check        # Type check without running
gleam format       # Format all Gleam source files
gleam deps         # Manage dependencies
```

### Quality Gates
Always run these after making changes:
1. `gleam format` - Format code
2. `gleam check` - Type check
3. `gleam test` - Run tests

## Project Structure
```
src/
├── homelab_system.gleam    # Main module
└── [future modules]

test/
├── homelab_system_test.gleam
└── [future test modules]
```

## Coding Conventions

### Gleam Style Guidelines
- Use snake_case for functions and variables
- Use PascalCase for types and constructors
- Prefer pattern matching over conditional logic
- Use pipes |> for data transformation chains
- Keep functions pure and side-effect free when possible

### Testing
- Use gleeunit for testing framework
- Test file names should match module names with `_test` suffix
- Write descriptive test names that explain the behavior being tested
- Group related tests using `describe` blocks when available

## Dependencies
- **gleam_stdlib**: Core standard library
- **gleeunit**: Testing framework (dev dependency)

## Git Workflow - GitHub Flow

### Branch Strategy
- **main**: Production-ready code, always deployable
- **feature branches**: All new features developed in separate branches
- **Branch naming**: Use descriptive names like `feature/server-monitoring` or `fix/memory-leak`

### Development Workflow
1. **Start new feature**:
   ```bash
   git checkout main
   git pull origin main
   git checkout -b feature/your-feature-name
   ```

2. **Development cycle**:
   ```bash
   make dev                    # Format, check, test
   git add .
   git commit -m "descriptive message"
   git push origin feature/your-feature-name
   ```

3. **Ready to merge**:
   ```bash
   # Create pull request via GitHub
   # After review and approval:
   git checkout main
   git pull origin main
   git branch -d feature/your-feature-name
   ```

### Commit Guidelines
- Use present tense: "Add server monitoring" not "Added server monitoring"
- First line under 50 characters
- Reference issues when applicable: "Fix memory leak (#123)"
- Make atomic commits (one logical change per commit)

### AI Agent Workflow Rules
- **ALWAYS** create a new branch for features: `git checkout -b feature/feature-name`
- **NEVER** push directly to main
- **ALWAYS** run `make dev` before committing
- Use descriptive branch and commit messages
- Push feature branch and mention when ready for PR

### Quick Commands
```bash
# Start new feature
make new-feature FEATURE=server-monitoring

# Development cycle  
make dev && git add . && git commit -m "message"

# Push feature branch
git push origin $(git branch --show-current)
```

## Common Tasks for AI Agents

### Adding New Features
1. **Create feature branch**: `git checkout -b feature/feature-name`
2. Create module in `src/`
3. Add corresponding test file in `test/`
4. Update imports in main module if needed
5. Run quality gates with `make dev`
6. Commit changes with descriptive message
7. Push branch: `git push origin feature/feature-name`
8. Ready for PR when complete

### Debugging Issues
1. Check type errors with `gleam check`
2. Run specific tests with `gleam test`
3. Use `io.debug()` for debugging (remove before committing)

### Refactoring
1. Make changes incrementally
2. Run tests after each change
3. Ensure all quality gates pass

## Homelab Context
This system is designed for:
- Server monitoring and management
- Service orchestration
- Configuration management
- Health checking and alerting
- Resource utilization tracking

Keep these use cases in mind when adding features or making architectural decisions.

## Notes for AI Agents
- Always run `gleam format` after editing code
- Gleam has a strong type system - leverage it for correctness
- Prefer functional patterns over imperative ones
- Keep the codebase simple and maintainable
- Document complex business logic with comments