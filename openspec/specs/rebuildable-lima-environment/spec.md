# rebuildable-lima-environment Specification

## Purpose

Provide an opt-in, version-controlled Lima development environment that can be rebuilt on a new Mac, operate Docker workloads through the macOS CLI, and safely separate normal source mounts from AI-agent synchronization.

## Requirements

### Requirement: Rebuildable Lima configuration

The repository SHALL provide declarative Lima configuration that defines the development VM shape independently from any VM disk or runtime state.

#### Scenario: Create a development VM from the repository
- **WHEN** a user runs the documented create command on a Mac with the required host dependencies
- **THEN** the command creates a named Lima development VM from the version-controlled configuration
- **AND** rerunning the command SHALL preserve an existing VM instead of deleting or recreating it implicitly

#### Scenario: Rebuild after VM loss
- **WHEN** the named VM no longer exists
- **THEN** the documented create flow SHALL recreate the VM and reinstall the declared guest dependencies
- **AND** the repository SHALL not require a checked-in VM disk or database data directory

### Requirement: Explicit Cider sharing and guest-native development state

The normal development VM SHALL mount only the declared Cider host directory. Project workspaces, Codex state, platform-specific dependencies, and persistent database storage SHALL remain on the guest disk.

#### Scenario: Use the mounted Cider directory
- **WHEN** the normal development VM is running
- **THEN** the configured host Cider directory SHALL be available at Lima's default guest mount point
- **AND** its write policy SHALL match the configuration
- **AND** guest `~/.cider` SHALL resolve to that mount

#### Scenario: Keep projects and Codex state guest-native
- **WHEN** the normal development VM is running
- **THEN** guest `~/doc` and `~/.codex` SHALL be real guest-side directories rather than host mounts or symlinks to macOS state
- **AND** the VM SHALL not override `CODEX_HOME` to a macOS path

#### Scenario: Connect to a forwarded service
- **WHEN** a container binds a declared guest port
- **THEN** the corresponding host port SHALL be reachable from macOS using the documented localhost address

#### Scenario: Keep database data in the VM
- **WHEN** a project starts PostgreSQL or another stateful Docker service
- **THEN** its named volume SHALL be stored inside the Lima VM
- **AND** the Cider configuration SHALL not mount a macOS directory as the live database data directory

### Requirement: macOS Docker CLI integration

The setup SHALL provide an explicit named Docker context that connects the macOS Docker CLI to the Docker Engine in the Lima VM through Lima's supported host Unix-socket forwarding.

#### Scenario: Select the Lima Docker engine
- **WHEN** the user runs the documented context setup command
- **THEN** the named context SHALL target the selected Lima VM through its forwarded Docker Unix socket
- **AND** `docker info` SHALL identify the Lima-hosted engine after the context is selected

#### Scenario: Run project Compose services
- **WHEN** the user selects the Lima context and runs a project's documented Compose command from its guest-native checkout
- **THEN** the Compose workload SHALL be created by the Docker Engine in Lima
- **AND** the project Compose definition SHALL remain owned by the project repository
- **AND** bind-mount source paths SHALL resolve in the Lima filesystem rather than the macOS filesystem

### Requirement: Isolated agent synchronization

The repository SHALL document a separate no-host-mount agent VM workflow that uses Lima shell synchronization for commands requiring an isolated copy of a project.

#### Scenario: Run an agent against a copied project
- **WHEN** the user starts the agent VM without host mounts and invokes `limactl shell --sync` for a project directory
- **THEN** the project SHALL be copied into the guest before the command runs
- **AND** changed content SHALL be reviewed before it is synchronized back to the host

#### Scenario: Prevent unsafe sync configuration
- **WHEN** the user attempts to use `--sync` with a VM that has host mounts configured
- **THEN** the workflow SHALL fail with an actionable explanation instead of treating the mounted directory as an isolated copy

### Requirement: Opt-in and safe lifecycle

Lima setup SHALL be opt-in and SHALL not remove, migrate, or alter existing OrbStack instances or persistent data.

#### Scenario: Run the general macOS bootstrap
- **WHEN** the user runs the existing general Cider macOS bootstrap
- **THEN** it SHALL not start the Lima VM or start project services automatically
- **AND** the user SHALL have a separate documented command to install or create the Lima environment

#### Scenario: Stop or remove the development VM
- **WHEN** the user runs a lifecycle command
- **THEN** stop and inspect operations SHALL be available without deleting data
- **AND** any destructive VM deletion command SHALL require an explicit user invocation and warn that guest-side volumes may be lost

### Requirement: Credential and runtime-state boundaries

The repository SHALL keep credentials, VM runtime state, Docker volumes, and project environment files outside version control.

#### Scenario: Separate operating-system-specific Codex state
- **WHEN** Codex runs on both macOS and the Lima guest
- **THEN** each operating system SHALL use its own `~/.codex` directory
- **AND** Linux releases, sessions, logs, sockets, and daemon state SHALL not be written into the macOS Codex directory

#### Scenario: Authenticate guest-native Git operations
- **WHEN** a guest-native project accesses an SSH Git remote
- **THEN** the development VM SHALL make the macOS SSH agent available to the guest
- **AND** the Cider provisioning SHALL not copy a host private key into the VM

#### Scenario: Inspect the publishable repository
- **WHEN** the user stages the Cider repository
- **THEN** Lima configuration and scripts SHALL be publishable
- **AND** VM disks, Docker data, secrets, private keys, and local environment files SHALL remain excluded
