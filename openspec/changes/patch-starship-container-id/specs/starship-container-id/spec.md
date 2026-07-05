# <starship-container-id Specification>
## Purpose

Provides a dynamic prompt modification for Fish shell environments inside containers. When a container environment is active, the system modifies the Starship prompt to display a truncated container identifier next to the directory segment. On the host or when not in a container, the default prompt layout is preserved.

## Requirements

### Requirement: Host Prompt Preservation

When the shell is initiated outside of a container environment, the default prompt configuration MUST be loaded without modification.

#### Scenario: Shell startup on host

- GIVEN the shell is started on the host
- AND the environment variable CONTAINER_ID is unset
- WHEN Starship initializes
- THEN the default prompt layout is rendered without the container ID segment

### Requirement: Container ID Prompt Modification

When the shell is initiated within a container environment, the prompt format MUST display the container identifier immediately following the directory segment.

#### Scenario: Shell startup inside a container

- GIVEN the shell is started in a container
- AND the environment variable CONTAINER_ID is set to "dev-env"
- WHEN Starship initializes
- THEN the custom prompt layout is rendered displaying "dev-env" after the directory segment

### Requirement: Hexadecimal Container ID Truncation

The system MUST truncate 64-character hexadecimal container identifiers to 12 characters when displaying them in the prompt. Shorter or non-hexadecimal identifiers MUST NOT be truncated.

#### Scenario: Truncating a long hexadecimal container ID

- GIVEN the environment variable CONTAINER_ID is set to "a1b2c3d4e5f67890abcdef1234567890abcdef1234567890abcdef1234567890"
- WHEN the custom prompt configuration is generated
- THEN the prompt displays "a1b2c3d4e5f6"

#### Scenario: Displaying a short or non-hex container ID

- GIVEN the environment variable CONTAINER_ID is set to "my-container"
- WHEN the custom prompt configuration is generated
- THEN the prompt displays "my-container"

### Requirement: Prompt Customization Caching

The dynamic prompt configuration MUST be cached to minimize startup latency. The cached configuration MUST only be regenerated when the base configuration is newer than the cache.

#### Scenario: Using a valid cached configuration

- GIVEN a cached custom configuration exists
- AND the base configuration is not newer than the cached configuration
- WHEN the shell starts
- THEN the cached configuration is loaded directly

#### Scenario: Regenerating stale cached configuration

- GIVEN the base configuration is newer than the cached configuration
- WHEN the shell starts
- THEN the custom configuration is regenerated and written to cache

### Requirement: Writable Directory Fallback

If the default cache directory is not writable, the system MUST fall back to caching in `/tmp`.

#### Scenario: Cache directory not writable

- GIVEN the default cache directory is read-only
- WHEN the shell starts and prompt regeneration is required
- THEN the configuration is written to `/tmp/starship_custom.toml`
- AND Starship initializes using the configuration in `/tmp/starship_custom.toml`
