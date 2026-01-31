class_name IsometricMath
extends RefCounted

## Isometric coordinate conversion utilities for the TheaterCity project.
## Consolidates duplicate isometric math from multiple files.

# Tile dimensions for isometric conversion (visual size after 0.5 scale)
const TILE_WIDTH := 64.0
const TILE_HEIGHT := 32.0
const HALF_WIDTH := TILE_WIDTH / 2.0
const HALF_HEIGHT := TILE_HEIGHT / 2.0

## Convert screen position to tile coordinates
static func screen_to_tile(screen_pos: Vector2, viewport: Viewport) -> Vector2i:
	# Convert screen position to world position
	var canvas_transform = viewport.get_canvas_transform()
	var world_pos = canvas_transform.affine_inverse() * screen_pos
	# Offset to align with tile center (adjust for tile origin)
	world_pos.y -= HALF_HEIGHT
	# Isometric to tile conversion
	var tile_x = (world_pos.x / HALF_WIDTH + world_pos.y / HALF_HEIGHT) / 2.0
	var tile_y = (world_pos.y / HALF_HEIGHT - world_pos.x / HALF_WIDTH) / 2.0
	return Vector2i(floor(tile_x), floor(tile_y))

## Convert tile coordinates to world position (top corner of tile)
static func tile_to_world(tile_pos: Vector2i) -> Vector2:
	return Vector2(
		(tile_pos.x - tile_pos.y) * HALF_WIDTH,
		(tile_pos.x + tile_pos.y) * HALF_HEIGHT + HALF_HEIGHT
	)

## Convert tile coordinates (float) to world position
static func tile_to_world_float(tile_pos: Vector2) -> Vector2:
	return Vector2(
		(tile_pos.x - tile_pos.y) * HALF_WIDTH,
		(tile_pos.x + tile_pos.y) * HALF_HEIGHT + HALF_HEIGHT
	)

## Convert tile coordinates to screen position
static func tile_to_screen(tile_pos: Vector2i, viewport: Viewport) -> Vector2:
	var world_pos = tile_to_world(tile_pos)
	var canvas_transform = viewport.get_canvas_transform()
	return canvas_transform * world_pos

## Convert UI tile coordinates to tilemap tile coordinates
## Uses doubled offset to shift tiles down-right to correct position
static func ui_to_tilemap_coords(ui_tile: Vector2i, tilemap_layer: TileMapLayer) -> Vector2i:
	# Double the offset to shift tiles down-right to correct position
	var world_pos = Vector2(
		(ui_tile.x - ui_tile.y) * HALF_WIDTH,
		(ui_tile.x + ui_tile.y) * HALF_HEIGHT + 2 * HALF_HEIGHT
	)
	var local_pos = tilemap_layer.to_local(world_pos)
	return tilemap_layer.local_to_map(local_pos)


## Convert tilemap tile coordinates back to UI tile coordinates
## Inverse of ui_to_tilemap_coords
static func tilemap_to_ui_coords(tilemap_pos: Vector2i, tilemap_layer: TileMapLayer) -> Vector2i:
	# Convert tilemap position to local position (center of tile)
	var local_pos = tilemap_layer.map_to_local(tilemap_pos)
	# Convert to world position
	var world_pos = tilemap_layer.to_global(local_pos)
	# Reverse the offset we applied in ui_to_tilemap_coords
	world_pos.y -= 2 * HALF_HEIGHT
	# Convert from isometric world to UI tile coords
	var tile_x = (world_pos.x / HALF_WIDTH + world_pos.y / HALF_HEIGHT) / 2.0
	var tile_y = (world_pos.y / HALF_HEIGHT - world_pos.x / HALF_WIDTH) / 2.0
	return Vector2i(round(tile_x), round(tile_y))

## Calculate isometric image dimensions for a given tile size
static func get_isometric_image_size(tile_size: Vector2i) -> Vector2i:
	return Vector2i(
		int((tile_size.x + tile_size.y) * HALF_WIDTH),
		int((tile_size.x + tile_size.y) * HALF_HEIGHT) + int(HALF_HEIGHT)
	)

## Calculate tile center position in image space for isometric drawing
static func get_tile_center_in_image(tx: int, ty: int, total_size: Vector2i) -> Vector2:
	return Vector2(
		(tx - ty) * HALF_WIDTH + total_size.y * HALF_WIDTH,
		(tx + ty) * HALF_HEIGHT + HALF_HEIGHT
	)
