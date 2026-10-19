class_name ChangeItem
extends Resource
## One line of work in a work order: add, remove or replace what sits in a ship slot.

const ADD := "add"
const REMOVE := "remove"
const REPLACE := "replace"
const ACTIONS: PackedStringArray = [ADD, REMOVE, REPLACE]

## Progress of one change, set by Ship and Bay and Quality.
const PENDING := "pending"
const STRIPPED := "stripped"
const INSTALLED := "installed"
const INSPECTED := "inspected"
const FAILED := "failed"
const STATUSES: PackedStringArray = [PENDING, STRIPPED, INSTALLED, INSPECTED, FAILED]

@export var change_id := ""
@export var action := ADD
## A named module slot on the ship design.
@export var slot := ""
## What comes out (remove, replace), or null.
@export var remove: ComponentRef
## What goes in (add, replace), or null.
@export var install: ComponentRef
@export var notes := ""


func needs_install() -> bool:
	return action != REMOVE


func needs_removal() -> bool:
	return action != ADD
