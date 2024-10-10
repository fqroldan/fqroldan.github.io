include("cakeeating.jl")
print("Loading Interpolations.jl-based version…")

using Interpolations, Optim

function eval_value(kpv, kv, itp_v::AbstractInterpolation, ce::CakeEating)
	## Evalúa la función de valor en kv cuando se eligió kpv
	β, r = ce.pars[:β], ce.pars[:r]

	cv = budget_constraint(kpv, kv, r)

	cv > 0 || throw(error("Consumo negativo!!!!!"))
	
	# Utilidad de consumir cv
	ut = u(cv, ce)

	# Evalúa la interpolación de la función de valor en kpv (nivel, no índice)
	vp = itp_v(kpv)

	v = ut + β * vp

	return v
end

function opt_value(jk, itp_v::AbstractInterpolation, ce::CakeEating)
	## Optimiza la función de valor en el jk-ésimo estado usando el interpolador
	kv = ce.kgrid[jk]

	r = ce.pars[:r]
	
	k_min = minimum(ce.kgrid)
	k_max = kv * (1+r) - 1e-10 # dejando al menos 1e-10 para consumo
    k_max = min(k_max, maximum(ce.kgrid))

	# Función objetivo
	obj_f(kpv) = eval_value(kpv, kv, itp_v, ce)

	# Optimizador, eligiendo k entre k_min y k_max, algoritmo de sección dorada
	res = Optim.maximize(obj_f, k_min, k_max)

	# Guardo la solución, mínimo (con un menos de nuevo), minimizador, y el consumo implicado
	vp = Optim.maximum(res)
	k_star = Optim.maximizer(res)
	c_star = budget_constraint(k_star, kv, r)

	return k_star, vp, c_star
end

function vfi_iter!(new_v, itp_v::AbstractInterpolation, ce::CakeEating)
	## Una iteración usando el interpolador y guardar en new_v
	# Recorre los estados posibles para hoy
	for jk in eachindex(ce.kgrid)

		# Elige ahorro y consumo CON el interpolador
		k_star, vp, c_star = opt_value(jk, itp_v, ce)

		new_v[jk] = vp
		ce.gc[jk] = c_star
		ce.gk[jk] = k_star
	end
end

function vfi_itp!(ce::CakeEating; tol = 1e-8, maxiter = 2000, verbose = true)
	## Itera sobre la ecuación de Bellman con interpolaciones
	new_v = similar(ce.v)
	# Nombre para los puntos sobre los que interpolar
	knts = (ce.kgrid,)

	dist = 1+tol
	iter = 0

	while dist > tol && iter < maxiter
		iter += 1
		
		# Interpolador de la función de valor
		itp_v = interpolate(knts, ce.v, Gridded(Linear()))
		
		# Una iteración: ojo! multiple dispatch va a seleccionar el método de arriba y no el de "cakeeating.jl"!
		vfi_iter!(new_v, itp_v, ce)

		# Distancia
		dist = norm(new_v - ce.v) / norm(ce.v)

		# Actualización
		ce.v .= new_v
	end
	verbose && print("Iteration $iter. Distance = $dist\n")
	dist < tol && print("✓")
end

print(" ✓\nSolver with interpolations: vfi_itp!(ce::CakeEating)\n")