class_name MovieGenerator
extends RefCounted

## Procedural movie generation for theater simulation.
## Uses RandomNumberGenerator for reproducible generation with set_seed().

const GENRES := ["Action", "Comedy", "Drama", "Horror", "Sci-Fi", "Romance", "Thriller", "Animation"]

const TITLE_ADJECTIVES := [
	"The Great", "Dark", "Lost", "Final", "Secret", "Eternal", "Hidden", "Last",
	"Midnight", "Golden", "Silver", "Crimson", "Frozen", "Burning", "Silent"
]

const TITLE_NOUNS := [
	"Journey", "Mystery", "Kingdom", "Storm", "Heart", "Shadow", "Legend", "Dawn",
	"Empire", "Quest", "Dreams", "Destiny", "Secrets", "Paradise", "Horizon"
]

var rng: RandomNumberGenerator
var _id_counter: int = 0


func _init() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = Time.get_unix_time_from_system()


## Generate a single random movie.
func generate_movie() -> MovieResource:
	var movie = MovieResource.new()
	movie.id = "movie_%d_%d" % [Time.get_unix_time_from_system(), _id_counter]
	_id_counter += 1
	movie.title = _generate_title()
	movie.genre = GENRES[rng.randi_range(0, GENRES.size() - 1)]
	movie.rating = rng.randi_range(30, 100)  # Never below 30 to avoid terrible movies
	movie.duration = rng.randi_range(80, 180)  # Standard movie length range
	return movie


## Generate a random title from adjective + noun combinations.
func _generate_title() -> String:
	var adj = TITLE_ADJECTIVES[rng.randi_range(0, TITLE_ADJECTIVES.size() - 1)]
	var noun = TITLE_NOUNS[rng.randi_range(0, TITLE_NOUNS.size() - 1)]
	return "%s %s" % [adj, noun]


## Generate a pool of random movies.
## If count <= 0, generates a random number between 5 and 8 movies.
func generate_pool(count: int = 0) -> Array[MovieResource]:
	var pool: Array[MovieResource] = []
	var actual_count = count if count > 0 else rng.randi_range(5, 8)
	for i in range(actual_count):
		pool.append(generate_movie())
	return pool


## Set seed for reproducible generation (useful for testing).
func set_seed(seed_value: int) -> void:
	rng.seed = seed_value
	_id_counter = 0
