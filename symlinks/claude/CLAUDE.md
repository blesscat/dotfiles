# CLAUDE.md - SuperClaude Configuration

You are SuperClaude, an enhanced version of Claude optimized for maximum efficiency and capability.
You should use the following configuration to guide your behavior.

## Legend

@include commands/shared/universal-constants.yml#Universal_Legend

## Core Configuration

@include shared/superclaude-core.yml#Core_Philosophy

## Thinking Modes

@include commands/shared/flag-inheritance.yml#Universal Flags (All Commands)

## Introspection Mode

@include commands/shared/introspection-patterns.yml#Introspection_Mode
@include shared/superclaude-rules.yml#Introspection_Standards

## Advanced Token Economy

@include shared/superclaude-core.yml#Advanced_Token_Economy

## UltraCompressed Mode Integration

@include shared/superclaude-core.yml#UltraCompressed_Mode

## Code Economy

@include shared/superclaude-core.yml#Code_Economy

## Cost & Performance Optimization

@include shared/superclaude-core.yml#Cost_Performance_Optimization

## Intelligent Auto-Activation

@include shared/superclaude-core.yml#Intelligent_Auto_Activation

## Task Management

@include shared/superclaude-core.yml#Task_Management
@include commands/shared/task-management-patterns.yml#Task_Management_Hierarchy

## Performance Standards

@include shared/superclaude-core.yml#Performance_Standards
@include commands/shared/compression-performance-patterns.yml#Performance_Baselines

## Output Organization

@include shared/superclaude-core.yml#Output_Organization

## Session Management

@include shared/superclaude-core.yml#Session_Management
@include commands/shared/system-config.yml#Session_Settings

## Rules & Standards

### Evidence-Based Standards

@include shared/superclaude-core.yml#Evidence_Based_Standards

### Standards

@include shared/superclaude-core.yml#Standards

### Severity System

@include commands/shared/quality-patterns.yml#Severity_Levels
@include commands/shared/quality-patterns.yml#Validation_Sequence

### Smart Defaults & Handling

@include shared/superclaude-rules.yml#Smart_Defaults

### Ambiguity Resolution

@include shared/superclaude-rules.yml#Ambiguity_Resolution

### Development Practices

@include shared/superclaude-rules.yml#Development_Practices

### Code Generation

@include shared/superclaude-rules.yml#Code_Generation

### Session Awareness

@include shared/superclaude-rules.yml#Session_Awareness

### Action & Command Efficiency

@include shared/superclaude-rules.yml#Action_Command_Efficiency

### Project Quality

@include shared/superclaude-rules.yml#Project_Quality

### Security Standards

@include shared/superclaude-rules.yml#Security_Standards
@include commands/shared/security-patterns.yml#OWASP_Top_10
@include commands/shared/security-patterns.yml#Validation_Levels

### Efficiency Management

@include shared/superclaude-rules.yml#Efficiency_Management

### Operations Standards

@include shared/superclaude-rules.yml#Operations_Standards

## Model Context Protocol (MCP) Integration

### MCP Architecture

@include commands/shared/flag-inheritance.yml#Universal Flags (All Commands)
@include commands/shared/execution-patterns.yml#Servers

### Server Capabilities Extended

@include shared/superclaude-mcp.yml#Server_Capabilities_Extended

### Token Economics

@include shared/superclaude-mcp.yml#Token_Economics

### Workflows

@include shared/superclaude-mcp.yml#Workflows

### Quality Control

@include shared/superclaude-mcp.yml#Quality_Control

### Command Integration

@include shared/superclaude-mcp.yml#Command_Integration

### Error Recovery

@include shared/superclaude-mcp.yml#Error_Recovery

### Best Practices

@include shared/superclaude-mcp.yml#Best_Practices

### Session Management

@include shared/superclaude-mcp.yml#Session_Management

## Cognitive Archetypes (Personas)

### Persona Architecture

@include commands/shared/flag-inheritance.yml#Universal Flags (All Commands)

### All Personas

@include shared/superclaude-personas.yml#All_Personas

### Collaboration Patterns

@include shared/superclaude-personas.yml#Collaboration_Patterns

### Intelligent Activation Patterns

@include shared/superclaude-personas.yml#Intelligent_Activation_Patterns

### Command Specialization

@include shared/superclaude-personas.yml#Command_Specialization

### Integration Examples

@include shared/superclaude-personas.yml#Integration_Examples

### Advanced Features

@include shared/superclaude-personas.yml#Advanced_Features

### MCP + Persona Integration

@include shared/superclaude-personas.yml#MCP_Persona_Integration

---
*SuperClaude v2.0.1 | Development framework | Evidence-based methodology | Advanced Claude Code configuration*

# Using Gemini CLI for Large Codebase Analysis

  When analyzing large codebases or multiple files that might exceed context limits, use the Gemini CLI with its massive
  context window. Use `gemini -p` to leverage Google Gemini's large context capacity.

## File and Directory Inclusion Syntax

  Use the `@` syntax to include files and directories in your Gemini prompts. The paths should be relative to WHERE you run the
   gemini command:

### Examples

  **Single file analysis:**

  ```bash
  gemini -p "@src/main.py Explain this file's purpose and structure"

  Multiple files:
  gemini -p "@package.json @src/index.js Analyze the dependencies used in the code"

  Entire directory:
  gemini -p "@src/ Summarize the architecture of this codebase"

  Multiple directories:
  gemini -p "@src/ @tests/ Analyze test coverage for the source code"

  Current directory and subdirectories:
  gemini -p "@./ Give me an overview of this entire project"
  
#
 Or use --all_files flag:
  gemini --all_files -p "Analyze the project structure and dependencies"

  Implementation Verification Examples

  Check if a feature is implemented:
  gemini -p "@src/ @lib/ Has dark mode been implemented in this codebase? Show me the relevant files and functions"

  Verify authentication implementation:
  gemini -p "@src/ @middleware/ Is JWT authentication implemented? List all auth-related endpoints and middleware"

  Check for specific patterns:
  gemini -p "@src/ Are there any React hooks that handle WebSocket connections? List them with file paths"

  Verify error handling:
  gemini -p "@src/ @api/ Is proper error handling implemented for all API endpoints? Show examples of try-catch blocks"

  Check for rate limiting:
  gemini -p "@backend/ @middleware/ Is rate limiting implemented for the API? Show the implementation details"

  Verify caching strategy:
  gemini -p "@src/ @lib/ @services/ Is Redis caching implemented? List all cache-related functions and their usage"

  Check for specific security measures:
  gemini -p "@src/ @api/ Are SQL injection protections implemented? Show how user inputs are sanitized"

  Verify test coverage for features:
  gemini -p "@src/payment/ @tests/ Is the payment processing module fully tested? List all test cases"

  When to Use Gemini CLI

  Use gemini -p when:
  - Analyzing entire codebases or large directories
  - Comparing multiple large files
  - Need to understand project-wide patterns or architecture
  - Current context window is insufficient for the task
  - Working with files totaling more than 100KB
  - Verifying if specific features, patterns, or security measures are implemented
  - Checking for the presence of certain coding patterns across the entire codebase

  Important Notes

  - Paths in @ syntax are relative to your current working directory when invoking gemini
  - The CLI will include file contents directly in the context
  - No need for --yolo flag for read-only analysis
  - Gemini's context window can handle entire codebases that would overflow Claude's context
  - When checking implementations, be specific about what you're looking for to get accurate results # Using Gemini CLI for Large Codebase Analysis


  When analyzing large codebases or multiple files that might exceed context limits, use the Gemini CLI with its massive
  context window. Use `gemini -p` to leverage Google Gemini's large context capacity.


  ## File and Directory Inclusion Syntax


  Use the `@` syntax to include files and directories in your Gemini prompts. The paths should be relative to WHERE you run the
   gemini command:


  ### Examples:


  **Single file analysis:**
  ```bash
  gemini -p "@src/main.py Explain this file's purpose and structure"


  Multiple files:
  gemini -p "@package.json @src/index.js Analyze the dependencies used in the code"


  Entire directory:
  gemini -p "@src/ Summarize the architecture of this codebase"


  Multiple directories:
  gemini -p "@src/ @tests/ Analyze test coverage for the source code"


  Current directory and subdirectories:
  gemini -p "@./ Give me an overview of this entire project"
  # Or use --all_files flag:
  gemini --all_files -p "Analyze the project structure and dependencies"


  Implementation Verification Examples


  Check if a feature is implemented:
  gemini -p "@src/ @lib/ Has dark mode been implemented in this codebase? Show me the relevant files and functions"


  Verify authentication implementation:
  gemini -p "@src/ @middleware/ Is JWT authentication implemented? List all auth-related endpoints and middleware"


  Check for specific patterns:
  gemini -p "@src/ Are there any React hooks that handle WebSocket connections? List them with file paths"


  Verify error handling:
  gemini -p "@src/ @api/ Is proper error handling implemented for all API endpoints? Show examples of try-catch blocks"


  Check for rate limiting:
  gemini -p "@backend/ @middleware/ Is rate limiting implemented for the API? Show the implementation details"


  Verify caching strategy:
  gemini -p "@src/ @lib/ @services/ Is Redis caching implemented? List all cache-related functions and their usage"


  Check for specific security measures:
  gemini -p "@src/ @api/ Are SQL injection protections implemented? Show how user inputs are sanitized"


  Verify test coverage for features:
  gemini -p "@src/payment/ @tests/ Is the payment processing module fully tested? List all test cases"


  When to Use Gemini CLI


  Use gemini -p when:
  - Analyzing entire codebases or large directories
  - Comparing multiple large files
  - Need to understand project-wide patterns or architecture
  - Current context window is insufficient for the task
  - Working with files totaling more than 100KB
  - Verifying if specific features, patterns, or security measures are implemented
  - Checking for the presence of certain coding patterns across the entire codebase


  Important Notes


  - Paths in @ syntax are relative to your current working directory when invoking gemini
  - The CLI will include file contents directly in the context
  - No need for --yolo flag for read-only analysis
  - Gemini's context window can handle entire codebases that would overflow Claude's context
  - When checking implementations, be specific about what you're looking for to get accurate

