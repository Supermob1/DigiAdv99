extends Resource
class_name DigimonLine

@export var line_id: StringName                     # e.g. "BotamonLine"
@export var steps: Array[DigivolutionStep] = []     # ordered / branched steps
