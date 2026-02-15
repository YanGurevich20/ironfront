class_name MultiplayerProtocol
extends RefCounted

# Protocol versioning
const PROTOCOL_VERSION: int = 3

# ENet channel assignments
const CHANNEL_RELIABLE: int = 0
const CHANNEL_INPUT: int = 1
const CHANNEL_STATE: int = 2

# Replication rates
const INPUT_SEND_RATE_HZ: int = 60
const SNAPSHOT_RATE_HZ: int = 30

# Server-side input validation window
const MAX_INPUT_FUTURE_TICKS: int = 120
