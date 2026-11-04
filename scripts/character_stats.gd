class_name CharacterStats
extends Resource

@export var display_name: String = "A"
@export var color: Color = Color.WHITE
@export var speed: float = 230.0
@export var damages: Array[int] = [10, 14, 20]
@export var knockbacks: Array[float] = [150.0, 200.0, 300.0]
@export var attack_startup: Array[float] = [0.03, 0.04, 0.06]
@export var attack_active: Array[float] = [0.06, 0.07, 0.09]
@export var attack_recovery: Array[float] = [0.10, 0.10, 0.15]
@export var attack_ranges: Array[float] = [78.0, 90.0, 86.0]
@export var attack_range: float = 78.0
@export var switch_damage: int = 24
@export var skill_damage: int = 30
@export var skill_cooldown: float = 3.0

@export var max_hp: int = 100
@export var mark: String = ""
@export var mark_duration: float = 3.0
@export var projectile: bool = false
@export var victory_line: String = ""
@export var hurt_line: String = ""
@export var switch_line: String = ""
@export var icon_path: String = ""
@export var portrait_path: String = ""
@export var skill: SkillData
@export var switch_attack: ComboAttackData
