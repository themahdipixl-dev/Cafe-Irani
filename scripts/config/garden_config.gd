class_name GardenConfig
extends RefCounted
## Fixed conventions of the garden world. Do not change after art production started.

## Pixels per meter.
const PPM := 100.0
## Camera elevation (35.26 degrees) in radians.
const EL := 0.6155
## cos(45 deg) = sin(45 deg).
const ISO_K := 0.70711
## Half size of the garden ground in meters (x and z from -HALF to +HALF).
const HALF := 15.0

## Camera limits in screen pixels (garden + walls + towers).
const LIMIT_LEFT := -2250
const LIMIT_RIGHT := 2250
const LIMIT_TOP := -1700
const LIMIT_BOTTOM := 1450

# Palette
const LAPIS := Color("#2A4B9B")
const GOLD := Color("#D9A63C")
const STONE := Color("#D8C7A3")
const STONE_LIGHT := Color("#EBDDBF")
const TURQUOISE := Color("#3DB7C2")
const GROUND := Color("#E9E2D3")


## Converts a world position (meters) to a screen position (pixels).
## +x goes to the bottom-right, +z to the bottom-left, +y goes up.
static func world_to_screen(x: float, y: float, z: float) -> Vector2:
	return Vector2(
		ISO_K * (x - z) * PPM,
		(ISO_K * sin(EL) * (x + z) - cos(EL) * y) * PPM)


## Draw order for a thing standing at (x, z). Bigger = in front.
static func z_for(x: float, z: float) -> int:
	return roundi((x + z) * 100.0)
