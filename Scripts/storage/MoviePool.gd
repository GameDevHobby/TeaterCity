class_name MoviePool
extends RefCounted

## Runtime storage for available movies.
## Manages a collection of MovieResource instances with lookup by ID.

var available_movies: Array[MovieResource] = []


## Add a movie to the pool.
func add_movie(movie: MovieResource) -> void:
	available_movies.append(movie)


## Remove a movie by ID.
## Returns true if found and removed, false otherwise.
func remove_movie(movie_id: String) -> bool:
	for i in range(available_movies.size()):
		if available_movies[i].id == movie_id:
			available_movies.remove_at(i)
			return true
	return false


## Get a movie by ID.
## Returns null if not found.
func get_movie(movie_id: String) -> MovieResource:
	for movie in available_movies:
		if movie.id == movie_id:
			return movie
	return null


## Get all movies in the pool.
## Returns a duplicate of the array to prevent external modification.
func get_all_movies() -> Array[MovieResource]:
	return available_movies.duplicate()


## Get number of movies in the pool.
func size() -> int:
	return available_movies.size()


## Serialize pool to dictionary for JSON storage.
func to_dict() -> Dictionary:
	var movies_arr: Array = []
	for movie in available_movies:
		movies_arr.append(movie.to_dict())
	return {"movies": movies_arr}


## Create MoviePool from dictionary.
static func from_dict(data: Dictionary) -> MoviePool:
	var pool = MoviePool.new()
	# Clear and re-append to preserve typed array
	pool.available_movies.clear()
	var movies_data = data.get("movies", [])
	for movie_data in movies_data:
		if movie_data is Dictionary:
			pool.available_movies.append(MovieResource.from_dict(movie_data))
	return pool
