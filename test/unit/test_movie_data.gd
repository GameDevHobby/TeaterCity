class_name TestMovieData
extends GutTest

## Unit tests for Movie Data System
## Tests MovieResource serialization, MovieGenerator variety/reproducibility, and MoviePool persistence

# --- MovieResource Tests ---

func test_movie_resource_default_values() -> void:
	var movie = MovieResource.new()
	assert_eq(movie.rating, 50, "rating should default to 50")
	assert_eq(movie.duration, 90, "duration should default to 90")


func test_movie_resource_to_dict() -> void:
	var movie = MovieResource.new()
	movie.id = "test_123"
	movie.title = "Test Movie"
	movie.genre = "Action"
	movie.rating = 85
	movie.duration = 120

	var dict = movie.to_dict()

	assert_true(dict.has("id"), "dict should have id")
	assert_true(dict.has("title"), "dict should have title")
	assert_true(dict.has("genre"), "dict should have genre")
	assert_true(dict.has("rating"), "dict should have rating")
	assert_true(dict.has("duration"), "dict should have duration")
	assert_eq(dict.id, "test_123", "id should match")
	assert_eq(dict.title, "Test Movie", "title should match")
	assert_eq(dict.genre, "Action", "genre should match")
	assert_eq(dict.rating, 85, "rating should match")
	assert_eq(dict.duration, 120, "duration should match")


func test_movie_resource_from_dict() -> void:
	var dict = {
		"id": "from_dict_456",
		"title": "Restored Movie",
		"genre": "Comedy",
		"rating": 72,
		"duration": 105
	}

	var movie = MovieResource.from_dict(dict)

	assert_eq(movie.id, "from_dict_456", "id should be restored")
	assert_eq(movie.title, "Restored Movie", "title should be restored")
	assert_eq(movie.genre, "Comedy", "genre should be restored")
	assert_eq(movie.rating, 72, "rating should be restored")
	assert_eq(movie.duration, 105, "duration should be restored")


func test_movie_resource_from_dict_with_defaults() -> void:
	var movie = MovieResource.from_dict({})

	assert_eq(movie.id, "", "id should default to empty string")
	assert_eq(movie.title, "Unknown", "title should default to Unknown")
	assert_eq(movie.genre, "Drama", "genre should default to Drama")
	assert_eq(movie.rating, 50, "rating should default to 50")
	assert_eq(movie.duration, 90, "duration should default to 90")


func test_movie_resource_round_trip() -> void:
	var original = MovieResource.new()
	original.id = "round_trip_789"
	original.title = "Round Trip Film"
	original.genre = "Thriller"
	original.rating = 88
	original.duration = 145

	var dict = original.to_dict()
	var restored = MovieResource.from_dict(dict)

	assert_eq(restored.id, original.id, "id should survive round trip")
	assert_eq(restored.title, original.title, "title should survive round trip")
	assert_eq(restored.genre, original.genre, "genre should survive round trip")
	assert_eq(restored.rating, original.rating, "rating should survive round trip")
	assert_eq(restored.duration, original.duration, "duration should survive round trip")


# --- MovieGenerator Tests ---

func test_generator_creates_movie() -> void:
	var gen = MovieGenerator.new()
	var movie = gen.generate_movie()

	assert_not_null(movie, "movie should not be null")
	assert_true(movie is MovieResource, "movie should be MovieResource")
	assert_true(movie.id.length() > 0, "movie id should not be empty")
	assert_true(movie.title.length() > 0, "movie title should not be empty")


func test_generator_produces_varied_titles() -> void:
	var gen = MovieGenerator.new()
	var titles: Array[String] = []

	for i in range(10):
		var movie = gen.generate_movie()
		titles.append(movie.title)

	# Count unique titles
	var unique_titles: Dictionary = {}
	for title in titles:
		unique_titles[title] = true

	assert_true(unique_titles.size() >= 5, "should have at least 5 unique titles out of 10, got %d" % unique_titles.size())


func test_generator_produces_varied_genres() -> void:
	var gen = MovieGenerator.new()
	var genres: Array[String] = []

	for i in range(20):
		var movie = gen.generate_movie()
		genres.append(movie.genre)

	# Count unique genres
	var unique_genres: Dictionary = {}
	for genre in genres:
		unique_genres[genre] = true

	assert_true(unique_genres.size() >= 3, "should have at least 3 unique genres out of 20, got %d" % unique_genres.size())


func test_generator_rating_in_range() -> void:
	var gen = MovieGenerator.new()

	for i in range(50):
		var movie = gen.generate_movie()
		assert_true(movie.rating >= 30, "rating should be >= 30, got %d" % movie.rating)
		assert_true(movie.rating <= 100, "rating should be <= 100, got %d" % movie.rating)


func test_generator_duration_in_range() -> void:
	var gen = MovieGenerator.new()

	for i in range(50):
		var movie = gen.generate_movie()
		assert_true(movie.duration >= 80, "duration should be >= 80, got %d" % movie.duration)
		assert_true(movie.duration <= 180, "duration should be <= 180, got %d" % movie.duration)


func test_generator_unique_ids() -> void:
	var gen = MovieGenerator.new()
	var ids: Array[String] = []

	for i in range(10):
		var movie = gen.generate_movie()
		ids.append(movie.id)

	# Check all IDs are unique
	var unique_ids: Dictionary = {}
	for id in ids:
		assert_false(unique_ids.has(id), "ID should be unique: %s" % id)
		unique_ids[id] = true


func test_generator_seeded_reproducibility() -> void:
	var gen1 = MovieGenerator.new()
	gen1.set_seed(12345)

	var gen2 = MovieGenerator.new()
	gen2.set_seed(12345)

	for i in range(3):
		var movie1 = gen1.generate_movie()
		var movie2 = gen2.generate_movie()

		assert_eq(movie1.title, movie2.title, "titles should match with same seed (iteration %d)" % i)
		assert_eq(movie1.genre, movie2.genre, "genres should match with same seed (iteration %d)" % i)
		assert_eq(movie1.rating, movie2.rating, "ratings should match with same seed (iteration %d)" % i)
		assert_eq(movie1.duration, movie2.duration, "durations should match with same seed (iteration %d)" % i)


func test_generator_pool_default_size() -> void:
	var gen = MovieGenerator.new()
	var pool = gen.generate_pool()

	assert_true(pool.size() >= 5, "default pool should have at least 5 movies, got %d" % pool.size())
	assert_true(pool.size() <= 8, "default pool should have at most 8 movies, got %d" % pool.size())


func test_generator_pool_custom_size() -> void:
	var gen = MovieGenerator.new()
	var pool = gen.generate_pool(10)

	assert_eq(pool.size(), 10, "pool should have exactly 10 movies")


# --- MoviePool Tests ---

func test_pool_add_movie() -> void:
	var pool = MoviePool.new()
	var movie = MovieResource.new()
	movie.id = "add_test"

	pool.add_movie(movie)

	assert_eq(pool.size(), 1, "pool should have 1 movie after add")


func test_pool_remove_movie() -> void:
	var pool = MoviePool.new()
	var movie = MovieResource.new()
	movie.id = "remove_test"
	pool.add_movie(movie)

	var removed = pool.remove_movie("remove_test")
	assert_true(removed, "remove should return true for existing movie")
	assert_eq(pool.size(), 0, "pool should be empty after remove")

	var removed_again = pool.remove_movie("nonexistent")
	assert_false(removed_again, "remove should return false for nonexistent movie")


func test_pool_get_movie() -> void:
	var pool = MoviePool.new()
	var movie = MovieResource.new()
	movie.id = "get_test"
	movie.title = "Get Test Movie"
	pool.add_movie(movie)

	var found = pool.get_movie("get_test")
	assert_not_null(found, "should find movie by ID")
	assert_eq(found.id, "get_test", "found movie should have correct ID")

	var not_found = pool.get_movie("nonexistent")
	assert_null(not_found, "should return null for nonexistent ID")


func test_pool_size() -> void:
	var pool = MoviePool.new()

	for i in range(5):
		var movie = MovieResource.new()
		movie.id = "size_test_%d" % i
		pool.add_movie(movie)

	assert_eq(pool.size(), 5, "pool should have 5 movies")


func test_pool_to_dict() -> void:
	var pool = MoviePool.new()

	for i in range(3):
		var movie = MovieResource.new()
		movie.id = "to_dict_test_%d" % i
		movie.title = "Movie %d" % i
		pool.add_movie(movie)

	var dict = pool.to_dict()

	assert_true(dict.has("movies"), "dict should have movies key")
	assert_eq(dict.movies.size(), 3, "movies array should have 3 entries")


func test_pool_from_dict() -> void:
	var dict = {
		"movies": [
			{"id": "from_dict_0", "title": "First", "genre": "Action", "rating": 70, "duration": 100},
			{"id": "from_dict_1", "title": "Second", "genre": "Comedy", "rating": 80, "duration": 110},
			{"id": "from_dict_2", "title": "Third", "genre": "Drama", "rating": 90, "duration": 120}
		]
	}

	var pool = MoviePool.from_dict(dict)

	assert_eq(pool.size(), 3, "pool should have 3 movies from dict")


func test_pool_round_trip() -> void:
	var original_pool = MoviePool.new()
	var ids: Array[String] = []

	for i in range(5):
		var movie = MovieResource.new()
		movie.id = "round_trip_%d" % i
		movie.title = "Round Trip Movie %d" % i
		movie.genre = "Action"
		movie.rating = 50 + i * 10
		movie.duration = 90 + i * 10
		original_pool.add_movie(movie)
		ids.append(movie.id)

	var dict = original_pool.to_dict()
	var restored_pool = MoviePool.from_dict(dict)

	assert_eq(restored_pool.size(), 5, "restored pool should have 5 movies")

	# Verify all movies preserved by checking IDs
	for id in ids:
		var movie = restored_pool.get_movie(id)
		assert_not_null(movie, "movie with ID %s should exist in restored pool" % id)
