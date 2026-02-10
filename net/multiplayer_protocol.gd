class_name MultiplayerProtocol
extends RefCounted

# Protocol versioning
const PROTOCOL_VERSION: int = 1

# ENet channel assignments
const CHANNEL_RELIABLE: int = 0
const CHANNEL_INPUT: int = 1
const CHANNEL_STATE: int = 2

# Replication rates
const INPUT_SEND_RATE_HZ: int = 60
const SNAPSHOT_RATE_HZ: int = 30

# Server-side input validation window
const MAX_INPUT_FUTURE_TICKS: int = 120

# Minimal authoritative movement model for Phase 5 bootstrap
const SIM_MAX_LINEAR_SPEED: float = 360.0
const SIM_ACCELERATION: float = 920.0
const SIM_TURN_RATE_RADIANS: float = 2.6
