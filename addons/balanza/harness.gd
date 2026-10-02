extends RefCounted
## Arnés de Balanza: evalúa objetivos y mide valores, precios y poder con las fórmulas del propio juego.
## adapters/ts/harness.ts hace las mismas cuentas en el mismo orden: si cambias una, cambia la otra.
## GDScript no tiene excepciones: el primer problema se guarda en `error` y lo que queda devuelve vacío.

const FORMAT_VERSION := 1
## Formato más nuevo de plan.json que lee el arnés: un plan con algún order con step es del 2 (PLAN_FORMAT_VERSION en types.ts).
const PLAN_FORMAT_VERSION := 2
const WARNING_PREFIX := {"challenge": "challenge:", "stats": "stat:", "effects": "effect:", "items": "item:"}
## Cuantil 0,975 de la t de Student con 1 a 30 grados de libertad (ver tQuantile en adapters/ts/harness.ts).
const T975 := [
	12.706204736, 4.30265273, 3.182446305, 2.776445105, 2.570581836, 2.446911851, 2.364624252, 2.306004135, 2.262157163, 2.22813885, 2.20098516, 2.17881283,
	2.160368656, 2.144786688, 2.131449546, 2.119905299, 2.109815578, 2.10092204, 2.093024054, 2.085963447, 2.079613845, 2.073873068, 2.06865761, 2.063898562,
	2.059538553, 2.055529439, 2.051830516, 2.048407142, 2.045229642, 2.042272456,
]
## Si la pendiente a un lado y a otro del conjunto de referencia difiere más de esto (relativo a la mayor), la métrica se dobla ahí.
const KINK_ASYMMETRY := 0.5
## Si el valor de una estadística difiere más de estas veces entre dos escenarios, la mezcla la decide el de valor más alto.
const SCENARIO_SPREAD := 3.0
## Con un enlace estocástico, menos semillas que estas no dan un intervalo fiable.
const FEW_SEEDS := 8

var error := ""

var _binding
var _plan: Dictionary
var _items := {}
var _seeds: Array = []


func _init(plan: Dictionary, binding) -> void:
	_plan = plan
	_binding = binding
	var count := 1
	if bool(binding.capabilities().get("stochastic", false)):
		count = maxi(1, int(plan.get("seeds", 1)))
	for i in count:
		_seeds.append(i + 1)


func _fail(message: String) -> void:
	if error == "":
		error = message


func set_catalog(catalog: Dictionary) -> void:
	_items = {}
	for item in catalog.get("items", []):
		_items[item.id] = item


## Un objeto del catálogo tal y como lo ve el enlace, a una calidad.
static func to_build_item(item: Dictionary, quality: float) -> Dictionary:
	var stats := {}
	var bands := {}
	for stat in item.stats:
		var band: Dictionary = item.stats[stat]
		stats[stat] = float(band.min) + (float(band.max) - float(band.min)) * quality
		bands[stat] = {"min": float(band.min), "max": float(band.max)}
	var effects := []
	for e in item.effects:
		effects.append({"id": e.id, "params": e.params.duplicate()})
	return {"id": item.id, "slot": item.slot, "stats": stats, "bands": bands, "effects": effects}


static func virtual_item(id: String, stats: Dictionary) -> Dictionary:
	var bands := {}
	for stat in stats:
		bands[stat] = {"min": float(stats[stat]), "max": float(stats[stat])}
	return {"id": id, "slot": "", "virtual": true, "stats": stats.duplicate(), "bands": bands, "effects": []}


func make_build(plan_build: Dictionary) -> Dictionary:
	var out := []
	for entry in plan_build.items:
		if not _items.has(entry.id):
			_fail('el plan usa "%s", que no está en el catálogo' % entry.id)
			return {"items": [], "params": {}}
		out.append(to_build_item(_items[entry.id], float(entry.quality)))
	if plan_build.has("extra"):
		out.append(virtual_item("@extra", plan_build.extra))
	return {"items": out, "params": plan_build.params.duplicate()}


func _check_scenario(scenario: String) -> bool:
	var known: Array = _binding.scenarios()
	if not known.has(scenario.split(":")[0]):
		# Lo más habitual: scenarios() devuelve "duel:6" en vez de "duel"; el parámetro va en balance.json y en los objetivos
		var named := []
		for k in known:
			if String(k).contains(":"):
				named.append('"%s" en vez de "%s"' % [String(k).split(":")[0], k])
		var hint := ""
		if not named.is_empty():
			hint = ": scenarios() tiene que devolver nombres sin parámetro (%s); el parámetro va solo en balance.json y en los objetivos" % ", ".join(PackedStringArray(named))
		_fail('escenario desconocido "%s" (el enlace conoce: %s)%s' % [scenario, ", ".join(PackedStringArray(known)), hint])
		return false
	return true


func _metric_of(values: Dictionary, metric: String, scenario: String) -> float:
	var value = values.get(metric)
	if not (value is float or value is int) or is_nan(float(value)) or is_inf(float(value)):
		_fail('el enlace no devuelve la métrica "%s" en "%s"' % [metric, scenario])
		return 0.0
	return float(value)


## Media de una métrica sobre las semillas. El escenario "mix" pondera los escenarios del plan.
func mean_metric(build: Dictionary, scenario: String, metric: String) -> float:
	if scenario == "mix":
		var total := 0.0
		for name in _plan.scenarios:
			total += float(_plan.scenarios[name]) * mean_metric(build, name, metric)
		return total
	if not _check_scenario(scenario):
		return 0.0
	var sum := 0.0
	for seed_value in _seeds:
		sum += _metric_of(_binding.evaluate(build, scenario, seed_value), metric, scenario)
	return sum / _seeds.size()


static func _scale_of(x: float) -> float:
	return 1.0 if x == 0.0 else absf(x)


## Cada par consecutivo de un orden, con su margen y si cumple (orderPairs en harness.ts, en el mismo orden). Sin step, el
## siguiente tiene que superar al anterior; con step, la diferencia d cumple min ≤ d < max y el margen es el de una franja.
static func order_pairs(target: Dictionary, values: Array) -> Array:
	var pairs := []
	for i in values.size() - 1:
		var d: float = float(values[i + 1]) - float(values[i])
		if not target.has("step"):
			pairs.append({"margin": d / _scale_of(float(values[i])), "pass": float(values[i + 1]) > float(values[i])})
			continue
		var step: Dictionary = target.step
		var margin := INF
		if step.has("min"):
			margin = minf(margin, (d - float(step.min)) / _scale_of(float(step.min)))
		if step.has("max"):
			margin = minf(margin, (float(step.max) - d) / _scale_of(float(step.max)))
		var ok := (not step.has("min") or d >= float(step.min)) and (not step.has("max") or d < float(step.max))
		pairs.append({"margin": margin if margin != INF else 0.0, "pass": ok})
	return pairs


static func _median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	var mid := int(sorted.size() / 2.0)
	if sorted.size() % 2 == 1:
		return sorted[mid]
	return (sorted[mid - 1] + sorted[mid]) / 2.0


func evaluate_target(target: Dictionary) -> Dictionary:
	var scenario: String = target.scenario
	var metric: String = target.metric
	if target.type == "band":
		var v := mean_metric(make_build(target.build), scenario, metric)
		var margin := INF
		if target.has("min"):
			margin = minf(margin, (v - float(target.min)) / _scale_of(float(target.min)))
		if target.has("max"):
			margin = minf(margin, (float(target.max) - v) / _scale_of(float(target.max)))
		var ok := (not target.has("min") or v >= float(target.min)) and (not target.has("max") or v < float(target.max))
		return {"id": target.id, "type": "band", "values": [v], "margin": margin if margin != INF else 0.0, "pass": ok}
	if target.type == "order":
		var values := []
		for b in target.sequence:
			values.append(mean_metric(make_build(b), scenario, metric))
		var margin := INF
		var ok := true
		for pair in order_pairs(target, values):
			margin = minf(margin, pair.margin)
			ok = ok and pair.pass
		return {"id": target.id, "type": "order", "values": values, "margin": margin, "pass": ok}
	var members := []
	for m in target.members:
		members.append(mean_metric(make_build(m.build), scenario, metric))
	var med := _median(members)
	var worst := 0.0
	for v in members:
		worst = maxf(worst, absf(v - med) / _scale_of(med))
	var parity_margin := float(target.within) - worst
	return {"id": target.id, "type": "parity", "values": members, "margin": parity_margin, "pass": parity_margin >= 0.0}


func _check_variant(variant: String, catalog: Dictionary) -> Dictionary:
	set_catalog(catalog)
	var results := []
	for target in _plan.targets:
		results.append(evaluate_target(target))
		if error != "":
			return {}
	var worst := INF if results.size() > 0 else 0.0
	var failed := 0
	for r in results:
		worst = minf(worst, r.margin)
		if not r.pass:
			failed += 1
	return {"variant": variant, "results": results, "failed": failed, "worstMargin": worst}


## Comprueba los objetivos del plan sobre un catálogo o, si `variants` no está vacío, sobre cada variante.
func run_check(catalog: Dictionary, variants: Dictionary) -> Dictionary:
	var out := []
	if not variants.is_empty():
		for v in variants.variants:
			if not v.game.is_empty() and not _binding.has_method("set_param"):
				_fail("el barrido cambia parámetros del juego y el enlace no tiene set_param")
				return {}
			for name in v.game:
				_binding.set_param(name, float(v.game[name]))
			out.append(_check_variant(v.id, v.catalog))
			if error != "":
				return {}
	else:
		out.append(_check_variant("base", catalog))
		if error != "":
			return {}
	return {"format": FORMAT_VERSION, "kitVersion": _plan.kitVersion, "harness": "godot", "planId": _plan.planId, "variants": out}


# ---------------------------------------------------------------- medidas

## Cuantil de la t de Student que multiplica al error típico para el intervalo del 95 %: con pocas semillas es bastante más
## ancho que el 1,96 de la normal (con 4 semillas, 3,18). De 31 a 60 grados de libertad se toma 2,0; desde 61, 1,96.
static func _t_quantile(df: int) -> float:
	if df < 1:
		return 0.0
	if df <= T975.size():
		return T975[df - 1]
	return 2.0 if df <= 60 else 1.96


## Media de las diferencias de las semillas y la semianchura de su intervalo del 95 %.
static func _summarize(diffs: Array) -> Dictionary:
	var sum := 0.0
	for d in diffs:
		sum += d
	var mean: float = sum / diffs.size()
	var half_width := 0.0
	if diffs.size() > 1:
		var squares := 0.0
		for d in diffs:
			squares += (d - mean) * (d - mean)
		half_width = _t_quantile(diffs.size() - 1) * sqrt(squares / (diffs.size() - 1) / diffs.size())
	return {"mean": mean, "halfWidth": half_width}


## m(b) − m(a) en cada escenario con peso, con las mismas semillas a los dos lados.
func _paired_diffs(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := {}
	for scenario in _plan.scenarios:
		var weight := float(_plan.scenarios[scenario])
		if weight == 0.0:
			continue
		if not _check_scenario(scenario):
			return {}
		var metric: String = _binding.measure_metric(scenario)
		var diffs := []
		for seed_value in _seeds:
			var vb := _metric_of(_binding.evaluate(b, scenario, seed_value), metric, scenario)
			var va := _metric_of(_binding.evaluate(a, scenario, seed_value), metric, scenario)
			diffs.append(vb - va)
		out[scenario] = _summarize(diffs)
	return out


## Como _paired_diffs entre `low` y `high`, y además evalúa `base` (el conjunto sin tocar, en medio) para ver si la
## métrica se dobla ahí: la pendiente de `low` a `base` frente a la de `base` a `high` en cada escenario. Devuelve
## {"diffs": ..., "asymmetry": x} con la mayor asimetría relativa que no se explica por el ruido (sin "asymmetry" si
## ninguna pasa de KINK_ASYMMETRY).
func _paired_diffs_with_kink(low: Dictionary, base: Dictionary, high: Dictionary) -> Dictionary:
	var out := {}
	var asymmetry := -1.0
	for scenario in _plan.scenarios:
		var weight := float(_plan.scenarios[scenario])
		if weight == 0.0:
			continue
		if not _check_scenario(scenario):
			return {"diffs": {}}
		var metric: String = _binding.measure_metric(scenario)
		var whole := []
		var left := []
		var right := []
		for seed_value in _seeds:
			var vh := _metric_of(_binding.evaluate(high, scenario, seed_value), metric, scenario)
			var vl := _metric_of(_binding.evaluate(low, scenario, seed_value), metric, scenario)
			var vb := _metric_of(_binding.evaluate(base, scenario, seed_value), metric, scenario)
			whole.append(vh - vl)
			left.append(vb - vl)
			right.append(vh - vb)
		out[scenario] = _summarize(whole)
		var l := _summarize(left)
		var r := _summarize(right)
		var biggest := maxf(absf(l.mean), absf(r.mean))
		var gap := absf(l.mean - r.mean)
		if biggest > 0.0 and gap / biggest > KINK_ASYMMETRY and gap > l.halfWidth + r.halfWidth:
			asymmetry = maxf(asymmetry, gap / biggest)
	var result := {"diffs": out}
	if asymmetry >= 0.0:
		result["asymmetry"] = asymmetry
	return result


static func _rel_noise(d: Dictionary) -> float:
	if d.halfWidth == 0.0:
		return 0.0
	if d.mean == 0.0:
		return 1e9
	return d.halfWidth / absf(d.mean)


static func _total_of(build: Dictionary, stat: String) -> float:
	var total := 0.0
	for item in build.items:
		total += float(item.stats.get(stat, 0.0))
	return total


## δ = un número entero de pasos, al menos uno, cerca de `delta` × total de la estadística.
func _delta_for(build: Dictionary, stat: String, step: float) -> float:
	return maxf(1.0, roundf(float(_plan.measure.delta) * absf(_total_of(build, stat)) / step)) * step


func _with_delta(build: Dictionary, stat: String, amount: float) -> Dictionary:
	if _binding.has_method("with_delta"):
		return _binding.with_delta(build, stat, amount)
	var items: Array = build.items.duplicate()
	items.append(virtual_item("@delta:" + stat, {stat: amount}))
	return {"items": items, "params": build.params}


## Pendiente de la métrica respecto a una estadística en cada escenario; centrada si el conjunto tiene al menos δ. Con
## `check_kink` y pendiente centrada, evalúa además el conjunto sin tocar y da la asimetría entre las dos mitades.
## Devuelve {"slopes": ..., "asymmetry": x} (sin "asymmetry" si no hay codo).
func _slopes_and_kink(build: Dictionary, stat: Dictionary, check_kink: bool) -> Dictionary:
	var d := _delta_for(build, stat.id, float(stat.step))
	var centered := _total_of(build, stat.id) >= d
	var low := _with_delta(build, stat.id, -d) if centered else build
	var high := _with_delta(build, stat.id, d)
	var width := 2.0 * d if centered else d
	var measured := _paired_diffs_with_kink(low, build, high) if (centered and check_kink) else {"diffs": _paired_diffs(low, high)}
	var out := {}
	for scenario in measured.diffs:
		out[scenario] = {"mean": measured.diffs[scenario].mean / width, "halfWidth": measured.diffs[scenario].halfWidth / width}
	var result := {"slopes": out}
	if measured.has("asymmetry"):
		result["asymmetry"] = measured.asymmetry
	return result


func _slopes(build: Dictionary, stat: Dictionary) -> Dictionary:
	return _slopes_and_kink(build, stat, false).slopes


## Cuántas veces mayor es el valor de un escenario que el de otro (con signos opuestos o un cero, 1e9); 1 si hay un solo escenario.
static func _spread_of(by_scenario: Dictionary) -> float:
	var values: Array = by_scenario.values()
	if values.size() < 2:
		return 1.0
	var min_magnitude := INF
	var max_magnitude := 0.0
	var signs_differ := false
	for v in values:
		min_magnitude = minf(min_magnitude, absf(v))
		max_magnitude = maxf(max_magnitude, absf(v))
		if signf(v) != signf(values[0]):
			signs_differ = true
	if max_magnitude == 0.0:
		return 1.0
	if min_magnitude == 0.0 or signs_differ:
		return 1e9
	return max_magnitude / min_magnitude


## Cociente numerador / referencia en cada escenario, mezclado con los pesos de los escenarios.
func _mix_ratio(num: Dictionary, ref: Dictionary) -> Dictionary:
	var value := 0.0
	var weight := 0.0
	var noise := 0.0
	var by_scenario := {}
	var flat := []
	for scenario in _plan.scenarios:
		var w := float(_plan.scenarios[scenario])
		if not num.has(scenario) or not ref.has(scenario):
			continue
		var n: Dictionary = num[scenario]
		var r: Dictionary = ref[scenario]
		if r.mean == 0.0:
			flat.append(scenario)
			continue
		var ratio: float = n.mean / r.mean
		by_scenario[scenario] = ratio
		value += w * ratio
		weight += w
		# El ruido de un cociente suma el del numerador y el de la referencia (la mayor de las dos lo subestima hasta un 40 %)
		noise = maxf(noise, sqrt(_rel_noise(n) * _rel_noise(n) + _rel_noise(r) * _rel_noise(r)))
	return {"value": value / weight if weight > 0.0 else 0.0, "noise": noise, "byScenario": by_scenario, "flat": flat}


func _reference_for(level: float) -> Dictionary:
	var best = null
	for r in _plan.measure.references:
		var d := absf(float(r.level) - level)
		var best_d := absf(float(best.level) - level) if best != null else INF
		if d < best_d or (d == best_d and best != null and float(r.level) < float(best.level)):
			best = r
	if best == null:
		return {"items": [], "params": {"level": level}}
	return best.build


func _without_slot(build: Dictionary, slot: String) -> Dictionary:
	var items := []
	for b in build.items:
		if not (_items.has(b.id) and _items[b.id].slot == slot):
			items.append(b)
	var out := {"items": items, "params": build.params.duplicate()}
	if build.has("extra"):
		out.extra = build.extra.duplicate()
	return out


## Diferencia de un objeto o de un efecto en puntos de la referencia (pendiente de esta en el mismo conjunto).
func _to_points(d: Dictionary, reference: Dictionary, level: float, what: String, out: Dictionary) -> Dictionary:
	var m := _mix_ratio(d, reference)
	for scenario in m.flat:
		out.warnings.append({"kind": "flat-reference", "what": "%s:%s" % [what, scenario], "noise": 0.0})
	if m.noise > float(_plan.measure.maxNoise):
		out.warnings.append({"kind": "noise", "what": what, "noise": m.noise})
	return {"level": level, "points": m.value, "noise": m.noise, "byScenario": m.byScenario}


## Nivel como clave de JSON: "10" para 10, "2.5" para 2,5 (como String(x) en TypeScript).
static func level_key(x) -> String:
	var f := float(x)
	return str(int(f)) if f == floorf(f) else str(f)


func _measure_challenge(out: Dictionary) -> void:
	if not _binding.has_method("challenge"):
		_fail('la curva "measured" necesita challenge() en el enlace')
		return
	out.challenge = {}
	for level in _plan.measure.levels:
		out.challenge[level_key(level)] = float(_binding.challenge(float(level)))


func _measure_stats(out: Dictionary) -> void:
	out.stats = {}
	var reference: Dictionary = _plan.measure.stats[0]
	for lv in _plan.measure.levels:
		var level := level_key(lv)
		var base := make_build(_reference_for(float(lv)))
		var checked_ref := _slopes_and_kink(base, reference, true)
		var ref_slopes: Dictionary = checked_ref.slopes
		if error != "":
			return
		var flat := []
		for scenario in ref_slopes:
			if ref_slopes[scenario].mean == 0.0:
				flat.append(scenario)
		for scenario in flat:
			out.warnings.append({"kind": "flat-reference", "what": "stat:%s:%s" % [level, scenario], "noise": 0.0})
		if flat.size() == ref_slopes.size():
			continue
		if checked_ref.has("asymmetry"):
			out.warnings.append({"kind": "kink", "what": "stat:%s:%s" % [level, reference.id], "noise": 0.0, "factor": checked_ref.asymmetry})
		var own := _mix_ratio(ref_slopes, ref_slopes)
		var entry := {reference.id: {"value": 1.0, "noise": own.noise, "byScenario": own.byScenario}}
		for i in range(1, _plan.measure.stats.size()):
			var stat: Dictionary = _plan.measure.stats[i]
			var checked := _slopes_and_kink(base, stat, true)
			var m := _mix_ratio(checked.slopes, ref_slopes)
			if error != "":
				return
			entry[stat.id] = {"value": m.value, "noise": m.noise, "byScenario": m.byScenario}
			if m.noise > float(_plan.measure.maxNoise):
				out.warnings.append({"kind": "noise", "what": "stat:%s:%s" % [level, stat.id], "noise": m.noise})
			if checked.has("asymmetry"):
				out.warnings.append({"kind": "kink", "what": "stat:%s:%s" % [level, stat.id], "noise": 0.0, "factor": checked.asymmetry})
			var spread := _spread_of(m.byScenario)
			if spread > SCENARIO_SPREAD:
				out.warnings.append({"kind": "scenario-spread", "what": "stat:%s:%s" % [level, stat.id], "noise": 0.0, "factor": spread})
		out.stats[level] = entry


func _measure_effects(out: Dictionary) -> void:
	out.effects = {}
	if _plan.measure.effects.is_empty():
		return
	var ablation := bool(_binding.capabilities().get("ablation", false))
	if not ablation:
		for effect in _plan.measure.effects:
			if not bool(effect.get("ceilingOnly", false)):
				_fail("el enlace no permite quitar efectos (ablation: false): pon sus precios a mano en effects.csv")
				return
	var reference: Dictionary = _plan.measure.stats[0]
	for effect in _plan.measure.effects:
		# Sin ablation, un efecto de precio fijo que solo se mide por su techo se salta con un aviso
		if not ablation:
			out.warnings.append({"kind": "no-ablation", "what": "effect:%s" % effect.id, "noise": 0.0})
			continue
		out.effects[effect.id] = []
		for probe in effect.probes:
			if not _items.has(probe.item):
				_fail('el plan usa "%s", que no está en el catálogo' % probe.item)
				return
			var item: Dictionary = _items[probe.item]
			var base := make_build(_without_slot(_reference_for(float(probe.level)), item.slot))
			var plain := to_build_item(item, float(probe.quality))
			var without := plain.duplicate()
			var kept := []
			for e in plain.effects:
				if e.id != effect.id:
					kept.append(e)
			without.effects = kept
			var with_effect := plain
			if bool(probe.add):
				with_effect = plain.duplicate()
				var added: Array = plain.effects.duplicate()
				added.append({"id": effect.id, "params": probe.params.duplicate()})
				with_effect.effects = added
			var a_items: Array = base.items.duplicate()
			a_items.append(without)
			var b_items: Array = base.items.duplicate()
			b_items.append(with_effect)
			var a := {"items": a_items, "params": base.params}
			var b := {"items": b_items, "params": base.params}
			var d := _paired_diffs(a, b)
			var slopes := _slopes(a, reference)
			if error != "":
				return
			var what := "effect:%s:%s" % [effect.id, probe.item]
			var points := _to_points(d, slopes, float(probe.level), what, out)
			points.item = probe.item
			out.effects[effect.id].append(points)


func _measure_items(out: Dictionary) -> void:
	out.items = {}
	var reference: Dictionary = _plan.measure.stats[0]
	for m in _plan.measure.items:
		if not _items.has(m.id):
			_fail('el plan usa "%s", que no está en el catálogo' % m.id)
			return
		var item: Dictionary = _items[m.id]
		var base := make_build(_without_slot(_reference_for(float(m.level)), item.slot))
		var with_items: Array = base.items.duplicate()
		with_items.append(to_build_item(item, float(m.quality)))
		var with_item := {"items": with_items, "params": base.params}
		var d := _paired_diffs(base, with_item)
		var slopes := _slopes(base, reference)
		if error != "":
			return
		out.items[m.id] = _to_points(d, slopes, float(m.level), "item:%s" % m.id, out)


## Qué secciones pide el plan que measured.json aún no tiene (con `previous` del mismo plan).
func missing_sections(previous: Dictionary) -> Array:
	var missing := []
	if bool(_plan.measure.challenge) and previous.get("challenge", {}).is_empty():
		missing.append("challenge")
	if _plan.measure.stats.size() > 1 and previous.get("stats", {}).is_empty():
		missing.append("stats")
	if not _plan.measure.effects.is_empty() and previous.get("effects", {}).is_empty():
		missing.append("effects")
	if not _plan.measure.items.is_empty() and previous.get("items", {}).is_empty():
		missing.append("items")
	return missing


## measure.damping: cada valor recién medido se promedia con el de la medida anterior (damping × nuevo + (1 − damping) ×
## anterior), aunque el catálogo sea otro. Como las medidas dependen del catálogo y el catálogo de las medidas, medir y
## generar puede oscilar o derivar; promediar entre rondas lo amortigua. Solo toca las secciones que se acaban de medir.
## (adapters/ts/harness.ts hace las mismas cuentas en el mismo orden.)
func _dampen(out: Dictionary, previous: Dictionary, sections: Array) -> void:
	var damping := float(_plan.measure.get("damping", 1.0))
	if previous.is_empty() or not (damping < 1.0):
		return
	if sections.has("stats"):
		for level in out.stats:
			var before_level: Dictionary = previous.get("stats", {}).get(level, {})
			for stat in out.stats[level]:
				if before_level.has(stat):
					_mix(out.stats[level][stat], before_level[stat], "value", damping)
	if sections.has("effects"):
		for id in out.effects:
			var before_list: Array = previous.get("effects", {}).get(id, [])
			for entry in out.effects[id]:
				for before in before_list:
					if before.get("item", "") == entry.item and level_key(before.get("level", 0)) == level_key(entry.level):
						_mix(entry, before, "points", damping)
						break


func _mix(now: Dictionary, before: Dictionary, key: String, damping: float) -> void:
	if before.has(key) and (before[key] is float or before[key] is int):
		now[key] = damping * float(now[key]) + (1.0 - damping) * float(before[key])
	for scenario in now.byScenario:
		var old: Dictionary = before.get("byScenario", {})
		if old.has(scenario):
			now.byScenario[scenario] = damping * float(now.byScenario[scenario]) + (1.0 - damping) * float(old[scenario])


## Mide las secciones pedidas; sin ninguna, las que falten. Conserva las demás de `previous` si es del mismo plan.
func run_measure(catalog: Dictionary, requested: Array, previous: Dictionary) -> Dictionary:
	var keep := previous if (not previous.is_empty() and previous.get("planId", "") == _plan.planId) else {}
	var sections := requested if requested.size() > 0 else missing_sections(keep)
	var out := {
		"format": FORMAT_VERSION,
		"kitVersion": _plan.kitVersion,
		"harness": "godot",
		"planId": _plan.planId,
		"seeds": _seeds.size(),
		"stats": keep.get("stats", {}),
		"effects": keep.get("effects", {}),
		"items": keep.get("items", {}),
		"challenge": keep.get("challenge", {}),
		"warnings": [],
	}
	for w in keep.get("warnings", []):
		var dropped := false
		for s in sections:
			if String(w.what).begins_with(WARNING_PREFIX[s]):
				dropped = true
		if not dropped:
			out.warnings.append(w)
	set_catalog(catalog)
	if sections.has("challenge"):
		_measure_challenge(out)
	if sections.has("stats"):
		_measure_stats(out)
	if sections.has("effects"):
		_measure_effects(out)
	if sections.has("items"):
		_measure_items(out)
	# Con azar y pocas semillas no hay intervalo de confianza que valga (con una, el ruido sale 0 y no dice nada)
	var measured_something := false
	for s in sections:
		if s != "challenge":
			measured_something = true
	if measured_something:
		var kept := []
		for w in out.warnings:
			if w.kind != "few-seeds":
				kept.append(w)
		out.warnings = kept
		if bool(_binding.capabilities().get("stochastic", false)) and _seeds.size() < FEW_SEEDS:
			out.warnings.append({"kind": "few-seeds", "what": "seeds", "noise": float(_seeds.size())})
	if error == "":
		_dampen(out, previous, sections)
	return {} if error != "" else out


## Número para los mensajes: coma decimal y sin ceros sobrantes.
static func _num(x: float, decimals: int) -> String:
	var text := ("%." + str(decimals) + "f") % x
	if text.contains("."):
		text = text.rstrip("0").rstrip(".")
	if text == "-0":
		text = "0"
	return text.replace(".", ",")


## Lo que se le dice a quien diseña de un aviso de la medida (sin el «aviso:» del principio). `measured` da, para los
## avisos por escenario, el valor de cada uno. adapters/ts/harness.ts (warningText) dice lo mismo con las mismas palabras.
static func warning_text(w: Dictionary, measured: Dictionary) -> String:
	var stat := String(w.what).split(":")
	var factor := float(w.get("factor", 0.0))
	match String(w.kind):
		"noise":
			return "ruido alto en %s (±%s %%): sube measure.seeds" % [w.what, _num(float(w.noise) * 100.0, 0)]
		"no-ablation":
			return "no se midió el techo de %s: el enlace no permite quitar efectos (ablation: false)" % String(w.what).trim_prefix("effect:")
		"few-seeds":
			var seeds := int(w.noise)
			return "el enlace tiene azar y se midió con %d semilla%s: con menos de %d no hay intervalo de confianza que valga (con una, el ruido sale 0 aunque no lo sea): sube measure.seeds a %d o más" % [seeds, "" if seeds == 1 else "s", FEW_SEEDS, FEW_SEEDS]
		"scenario-spread":
			var by: Dictionary = measured.get("stats", {}).get(stat[1], {}).get(stat[2], {}).get("byScenario", {})
			var parts := PackedStringArray()
			for scenario in by:
				parts.append("%s %s" % [scenario, _num(float(by[scenario]), 3)])
			var list := " (%s)" % " · ".join(parts) if not by.is_empty() else ""
			var how := "tiene signo distinto o vale 0 en un escenario" if factor >= 1e9 else "es ×%s mayor en un escenario que en otro" % _num(factor, 1)
			return "el valor de %s (nivel %s) %s%s: la mezcla la decide el escenario donde la referencia casi no cuenta" % [stat[2], stat[1], how, list]
		"kink":
			return "la métrica se dobla donde se midió %s (nivel %s): su pendiente cambia un %s %% de un lado a otro del conjunto de referencia; ¿un tope o un umbral? Dale un valor a mano con scaling \"fixed\" o un max" % [stat[2], stat[1], _num(factor * 100.0, 0)]
	return "la estadística de referencia no mueve la métrica en %s" % w.what
