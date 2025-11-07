# Intentionally empty main.tf template at repo-level.
# The orchestrator (provision.py) generates a per-host main.tf inside
# build/<host>/tf that selects the correct module (Ubuntu or NixOS)
# and wires variables accordingly.

# See provider.tf, variables.tf, and outputs.tf for the common interface.