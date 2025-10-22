extends Node

var particles: Array = []

func add_particle(particle: Dictionary):
	particles.append(particle)

func update_particles(delta: float):
	for i in range(particles.size() - 1, -1, -1):
		var p = particles[i]
		if p["type"] == "spark":
			p["velocity"].y += 220 * delta
			p["position"] += p["velocity"] * delta
			p["timer"] += delta
			if p["timer"] >= 0.35:
				particles.remove_at(i)
		elif p["type"] == "pulse":
			p["timer"] -= delta
			if p["timer"] <= 0:
				particles.remove_at(i)

func draw_particles(canvas_item: CanvasItem, cam_x: float):
	for p in particles:
		if p["type"] == "spark":
			var alpha = clamp(1 - (p["timer"] / 0.35), 0, 1)
			canvas_item.draw_rect(Rect2(p["position"].x - cam_x, p["position"].y, 3, 3), Color(0xfd / 255.0, 0xde / 255.0, 0x47 / 255.0, alpha))
		elif p["type"] == "pulse":
			var radius = (1 - (p["timer"] / 0.35)) * 28
			var color = Color(0xea / 255.0, 0xb3 / 255.0, 0x08 / 255.0, 0.35)
			canvas_item.draw_arc(p["position"] - Vector2(cam_x, 0), radius, 0, TAU, 32, color, 2)