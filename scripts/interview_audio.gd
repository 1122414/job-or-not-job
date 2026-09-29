class_name InterviewAudio
extends Node3D

const CLIPS := {
	"paper":"res://assets/audio/interview/paper.wav",
	"chair":"res://assets/audio/interview/chair.wav",
	"box":"res://assets/audio/interview/box.wav",
	"phone":"res://assets/audio/interview/phone.wav"
}

var players: Dictionary = {}

func _ready() -> void:
	for kind in CLIPS:
		var player := AudioStreamPlayer3D.new()
		add_child(player)
		player.stream=load(CLIPS[kind])
		player.volume_db=-19.0
		player.bus="Interaction"
		player.unit_size=2.0
		player.max_distance=12.0
		players[kind]=player

func _exit_tree() -> void:
	for player in players.values():
		player.stop()
		player.stream=null

func cue(kind: String,position: Vector3) -> void:
	if not players.has(kind): return
	if DisplayServer.get_name()=="headless": return
	if not get_parent().soundscape.enabled: return
	var player: AudioStreamPlayer3D=players[kind]
	player.global_position=position
	player.play()
