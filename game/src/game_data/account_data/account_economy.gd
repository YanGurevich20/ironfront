class_name AccountEconomy
extends RefCounted

signal dollars_updated(new_dollars: int)
signal bonds_updated(new_bonds: int)

var dollars: int = 0:
	set(value):
		dollars = value
		dollars_updated.emit(value)
var bonds: int = 0:
	set(value):
		bonds = value
		bonds_updated.emit(value)
