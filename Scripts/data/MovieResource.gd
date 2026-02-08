class_name MovieResource
extends Resource

## Movie data model for theater scheduling and display.
## Pure data class with JSON serialization support.

@export var id: String
@export var title: String
@export var genre: String
@export var rating: int = 50  ## 0-100 quality scale (int to avoid JSON float issues)
@export var duration: int = 90  ## Runtime in minutes (int to avoid JSON float issues)


## Serialize movie to dictionary for JSON storage.
func to_dict() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"genre": genre,
		"rating": rating,
		"duration": duration
	}


## Create MovieResource from dictionary with safe defaults.
static func from_dict(data: Dictionary) -> MovieResource:
	var movie = MovieResource.new()
	movie.id = data.get("id", "")
	movie.title = data.get("title", "Unknown")
	movie.genre = data.get("genre", "Drama")
	movie.rating = data.get("rating", 50)
	movie.duration = data.get("duration", 90)
	return movie
