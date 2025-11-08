extends Resource
class_name DigivolutionStep

@export var from_name: StringName    # e.g. "Botamon"
@export var to_name: StringName      # e.g. "Koromon"

@export var min_level: int = 1       # required level (0 if not used)
@export var min_bond: int = 0        # required bond (0 if not used)

# Optional “special condition” tag, like "dark", "crest_courage", "virus"
# Leave empty ("") for normal evolution
@export var special_condition: StringName = &""
