class_name HazardStripes
extends RefCounted
## Diagonal yellow-and-black warning stripes, drawn once in code and mapped
## triplanar so they run the same on any box at any size. Marks what is not
## an ordinary door: a sealed Hatch, and the collar of a Boarding Pod.

const YELLOW := Color(0.95, 0.72, 0.1)
const BLACK := Color(0.06, 0.06, 0.07)
## Stripe repeats per metre.
const DENSITY := 1.6

static var _texture: ImageTexture


static func texture() -> ImageTexture:
	if _texture == null:
		var size := 64
		var image := Image.create(size, size, false, Image.FORMAT_RGB8)
		for x in size:
			for y in size:
				image.set_pixel(x, y, YELLOW if (x + y) % size < size / 2 else BLACK)
		image.generate_mipmaps()
		_texture = ImageTexture.create_from_image(image)
	return _texture


## A fresh striped material. Unlit by design: an emissive lift ignores the
## stripe texture and greys the black bands out.
static func material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = texture()
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * DENSITY
	# Matte paint: any gloss picks up the ship's grey reflection sky and
	# washes the black stripes out.
	m.metallic = 0.0
	m.metallic_specular = 0.1
	m.roughness = 1.0
	return m
