class_name FlagSet
extends Resource
## A set of feature flags: key -> on/off. config/project_flags.tres is the active set;
## config/release_profiles/v<major.minor>.tres says what each release switches on.
##
## Keys: "<module>" turns a whole module on ("trades"); "<module>.<feature>" turns on part
## of one ("trades.bolting"). A feature only counts as on when its module is on too.

@export var flags: Dictionary = {}
