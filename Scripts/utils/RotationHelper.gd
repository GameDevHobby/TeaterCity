class_name RotationHelper
extends RefCounted

## Rotation utilities for furniture placement in TheaterCity.
## Consolidates duplicate rotation logic from multiple files.

## Get size with dimensions swapped for 90/270 degree rotations
static func get_rotated_size(size: Vector2i, rotation: int) -> Vector2i:
	if needs_dimension_swap(rotation):
		return Vector2i(size.y, size.x)
	return size

## Check if rotation requires dimension swap (90 or 270 degrees)
static func needs_dimension_swap(rotation: int) -> bool:
	return rotation == 1 or rotation == 3

## Rotate a tile offset based on furniture rotation
## 0 (north): offset unchanged
## 1 (east): (x, y) -> (y, -x)
## 2 (south): (x, y) -> (-x, -y)
## 3 (west): (x, y) -> (-y, x)
static func rotate_tile_offset(offset: Vector2i, rotation: int) -> Vector2i:
	match rotation % 4:
		0:  # North - no rotation
			return offset
		1:  # East - 90 degrees CW
			return Vector2i(offset.y, -offset.x)
		2:  # South - 180 degrees
			return Vector2i(-offset.x, -offset.y)
		3:  # West - 270 degrees CW (90 CCW)
			return Vector2i(-offset.y, offset.x)
	return offset

## Get all tiles occupied by furniture at a position with rotation
static func get_footprint_tiles(position: Vector2i, size: Vector2i, rotation: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var rotated_size = get_rotated_size(size, rotation)

	for x in range(rotated_size.x):
		for y in range(rotated_size.y):
			tiles.append(position + Vector2i(x, y))
	return tiles

## Calculate center offset for multi-tile furniture (as float for proper centering)
static func get_center_offset(size: Vector2i, rotation: int) -> Vector2:
	var rotated_size = get_rotated_size(size, rotation)
	return Vector2(float(rotated_size.x) / 2.0, float(rotated_size.y) / 2.0)
