class_name CharacterStats
extends Resource

@export var display_name: String = "A"
@export var color: Color = Color.WHITE
@export var speed: float = 230.0
@export var damages: Array[int] = [10, 14, 20]
@export var knockbacks: Array[float] = [150.0, 200.0, 300.0]
@export var attack_durations: Array[float] = [0.22, 0.24, 0.34]
@export var attack_range: float = 78.0
@export var switch_damage: int = 24
@export var skill_damage: int = 30
@export var skill_cooldown: float = 3.0
