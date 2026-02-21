class_name AccountEconomy
extends Resource

signal dollars_updated(new_dollars: int)
signal bonds_updated(new_bonds: int)

@export var dollars: int = 0:
	set(value):
		dollars = value
		dollars_updated.emit(value)
@export var bonds: int = 0:
	set(value):
		bonds = value
		bonds_updated.emit(value)
