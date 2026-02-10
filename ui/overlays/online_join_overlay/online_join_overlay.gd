class_name OnlineJoinOverlay
extends BaseOverlay

signal retry_requested
signal close_requested
signal cancel_requested

enum JoinUiState {
	JOINING,
	SUCCESS,
	ERROR,
}

const SPINNER_FRAMES: Array[String] = ["|", "/", "-", "\\"]

var _join_ui_state: JoinUiState = JoinUiState.JOINING
var _spinner_frame_index: int = 0
var _spinner_elapsed_seconds: float = 0.0

@onready var title_label: Label = %TitleLabel
@onready var spinner_label: Label = %SpinnerLabel
@onready var status_label: Label = %StatusLabel
@onready var retry_button: Button = %RetryButton
@onready var cancel_button: Button = %CancelButton
@onready var close_button: Button = %CloseButton


func _ready() -> void:
	super._ready()
	Utils.connect_checked(
		retry_button.pressed,
		func() -> void:
			print("[ui][online_join_overlay] retry_pressed")
			retry_requested.emit()
	)
	Utils.connect_checked(
		cancel_button.pressed,
		func() -> void:
			print("[ui][online_join_overlay] cancel_pressed")
			cancel_requested.emit()
	)
	Utils.connect_checked(
		close_button.pressed,
		func() -> void:
			print("[ui][online_join_overlay] close_pressed")
			close_requested.emit()
	)
	begin()


func begin() -> void:
	print("[ui][online_join_overlay] begin")
	_set_join_ui_state(JoinUiState.JOINING)
	title_label.text = "JOINING ONLINE ARENA"
	_set_status_text("CONNECTING...")
	set_process(true)


func set_status(message: String, is_error: bool) -> void:
	print("[ui][online_join_overlay] set_status is_error=%s message=%s" % [is_error, message])
	if is_error:
		complete(false, message)
		return
	_set_join_ui_state(JoinUiState.JOINING)
	title_label.text = "JOINING ONLINE ARENA"
	_set_status_text(message)
	set_process(true)


func complete(success: bool, message: String) -> void:
	print("[ui][online_join_overlay] complete success=%s message=%s" % [success, message])
	if success:
		_set_join_ui_state(JoinUiState.SUCCESS)
		title_label.text = "ONLINE JOINED"
	else:
		_set_join_ui_state(JoinUiState.ERROR)
		title_label.text = "ONLINE JOIN FAILED"
	_set_status_text(message)
	set_process(false)


func _process(delta: float) -> void:
	if _join_ui_state != JoinUiState.JOINING:
		return
	_spinner_elapsed_seconds += delta
	if _spinner_elapsed_seconds < 0.15:
		return
	_spinner_elapsed_seconds = 0.0
	_spinner_frame_index = (_spinner_frame_index + 1) % SPINNER_FRAMES.size()
	spinner_label.text = SPINNER_FRAMES[_spinner_frame_index]


func _set_join_ui_state(next_state: JoinUiState) -> void:
	_join_ui_state = next_state
	match _join_ui_state:
		JoinUiState.JOINING:
			spinner_label.visible = true
			retry_button.visible = false
			cancel_button.visible = true
			close_button.visible = false
		JoinUiState.SUCCESS:
			spinner_label.visible = false
			retry_button.visible = false
			cancel_button.visible = false
			close_button.visible = true
		JoinUiState.ERROR:
			spinner_label.visible = false
			retry_button.visible = true
			cancel_button.visible = false
			close_button.visible = true


func _set_status_text(message: String) -> void:
	status_label.text = message.strip_edges()
