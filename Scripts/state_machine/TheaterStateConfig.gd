class_name TheaterStateConfig
extends RefCounted

const THEATER_ROOM_TYPE_ID := "theater_auditorium"

const DEFAULT_SCHEDULED_DURATION := 60
const DEFAULT_PREVIEWS_DURATION := 30
const DEFAULT_PLAYING_DURATION := 180
const DEFAULT_CLEANING_DURATION := 45


static func is_theater_room_type(room_type_id: String) -> bool:
	return room_type_id == THEATER_ROOM_TYPE_ID


static func is_theater_room(room: RoomInstance) -> bool:
	return room != null and is_theater_room_type(room.room_type_id)


static func build_state_definitions(
	scheduled_duration: int = DEFAULT_SCHEDULED_DURATION,
	previews_duration: int = DEFAULT_PREVIEWS_DURATION,
	playing_duration: int = DEFAULT_PLAYING_DURATION,
	cleaning_duration: int = DEFAULT_CLEANING_DURATION
) -> Dictionary[String, StateDefinition]:
	var definitions: Dictionary[String, StateDefinition] = {}
	definitions["idle"] = StateDefinition.new("idle", 0, "")
	definitions["scheduled"] = StateDefinition.new("scheduled", scheduled_duration, "previews")
	definitions["previews"] = StateDefinition.new("previews", previews_duration, "playing")
	definitions["playing"] = StateDefinition.new("playing", playing_duration, "cleaning")
	definitions["cleaning"] = StateDefinition.new("cleaning", cleaning_duration, "idle")
	return definitions
