## Prints the art direction decoded from the divine_inspiration seed (see presentation/art_direction.gd).
## Usage: godot --headless --path . -s tools/_print_art.gd
extends SceneTree


func _initialize() -> void:
	print("seed[%s] = %s" % [Art.TOPIC, Art.SEED])
	print("floor ", Art.FloorPattern.keys()[Art.floor_pattern], " contrast ", Art.floor_contrast, " tone ", Art.floor_tone)
	print("skin ", Art.SkinPattern.keys()[Art.skin], " body ", Art.body_width, " head ", Art.HeadShape.keys()[Art.head],
			" fang ", Art.fang_length, " eye ", Art.eye_size)
	print("ink ", Art.ink_width, " boil ", Art.boil_fps, " fps ", Art.boil_amount, " px, paper ", Art.paper_tone)
	print("prey ", Art.PreySpecies.keys()[Art.prey_species_a], "/", Art.PreySpecies.keys()[Art.prey_species_b],
			" nerves ", Art.prey_nerves, " size ", Art.prey_size)
	print("gore x", Art.gore_amount, " bones +", Art.extra_bones, " blood ", Art.blood)
	print("film grain ", Art.film_grain, " flicker ", Art.film_flicker, " scratches ", Art.film_scratches,
			" vignette ", Art.vignette)
	print("wall ", Art.WallStyle.keys()[Art.wall], " ornament ", Art.OrnamentStyle.keys()[Art.ornament], " zoom ", Art.zoom)
	quit()
