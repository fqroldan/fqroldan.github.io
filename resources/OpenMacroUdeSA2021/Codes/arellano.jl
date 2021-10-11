using QuantEcon, Optim, Interpolations, LinearAlgebra, PlotlyJS, Distributions

abstract type Deuda
end

struct Default <: Deuda
	pars::Dict{Symbol, Float64}

	bgrid::Vector{Float64}
	ygrid::Vector{Float64}
	Py::Matrix{Float64}

	v::Matrix{Float64}
	vR::Matrix{Float64}
	vD::Matrix{Float64}
	prob::Matrix{Float64}

	gc::Array{Float64, 3}
	gb::Array{Float64, 2}

	q::Matrix{Float64}
	qD::Matrix{Float64}
end
function Arellano_params()
	return Default(ℏ = 1, ρ = 1)
end

function Default(;
	β = 0.953,
	γ = 2,
	r = 0.017,
	θ = 0.282,
	χ = 0.005,

	ρ = 0.35,

	ℏ = 0.5,
	Δ = 0.1,

	ρy = 0.945,
	σy = 0.025,

	Nb = 200,
	Ny = 21,

	bmax = 0.9
	)

	κ = r + ρ

	pars = Dict(:β=>β, :γ=>γ, :r=>r, :θ=>θ, :χ=>χ, :ρ=>ρ, :κ=>κ, :ℏ=>ℏ, :Δ=>Δ, :ρy=>ρy, :σy=>σy)

	ychain = tauchen(Ny, ρy, σy, 0, 2)

	Py = ychain.p
	ygrid = exp.(ychain.state_values)

	bgrid = range(0, bmax, length=Nb)

	v = zeros(Nb, Ny)
	vR = zeros(Nb, Ny)
	vD = zeros(Nb, Ny)
	prob = zeros(Nb, Ny)

	gc = zeros(Nb, Ny, 2)
	gb = zeros(Nb, Ny)

	q = ones(Nb, Ny)
	qD = zeros(Nb, Ny)

	return Default(pars, bgrid, ygrid, Py, v, vR, vD, prob, gc, gb, q, qD)
end

function logsumexp(a::AbstractVector{<:Real})
	m = maximum(a)
	return m + log.(sum(exp.(a .- m)))
end

u(cv, dd::Deuda) = u(cv, dd.pars[:γ])
function u(cv, γ)
	cmin = 1e-5
	if cv < cmin
		# Por debajo de cmin, lineal con la derivada de u en cmin
		return u(cmin, γ) + (cv-cmin) * cmin^(-γ)
	else
		if γ == 1
			return log(cv)
		else
			return cv^(1-γ) / (1-γ)
		end
	end
end
defcost(yv, dd::Deuda) = defcost(yv, dd.pars[:Δ])
defcost(yv, Δ::Number) = yv * (1-Δ)

function budget_constraint(bpv, bv, yv, q, dd::Deuda)
	ρ, κ = (dd.pars[sym] for sym in (:ρ, :κ))

	# consumo es ingreso más ingresos por vender deuda nueva menos repago de deuda vieja
	cv = yv + q * (bpv - (1-ρ) * bv) - κ * bv
	return cv
end

function eval_value(jb, jy, bpv, itp_q, itp_v, dd::Deuda)
	""" Evalúa la función de valor en (b,y) para una elección de b' """
	β = dd.pars[:β]
	bv, yv = dd.bgrid[jb], dd.ygrid[jy]

	# Interpola el precio de la deuda para el nivel elegido
	qv = itp_q(bpv, yv)

	# Deduce consumo del estado, la elección de deuda nueva y el precio de la deuda nueva
	cv = budget_constraint(bpv, bv, yv, qv, dd)
	
	# Evalúa la función de utilidad en c
	ut = u(cv, dd)

	# Calcula el valor esperado de la función de valor interpolando en b'
	Ev = 0.0
	for (jyp, ypv) in enumerate(dd.ygrid)
		prob = dd.Py[jy, jyp]
		Ev += prob * itp_v(bpv, ypv)
	end

	# v es el flujo de hoy más el valor de continuación esperado descontado
	v = ut + β * Ev

	return v, cv
end

function opt_value(jb, jy, itp_q, itp_v, dd::Deuda)
	""" Elige b' en (b,y) para maximizar la función de valor """
	
	# b' ∈ bgrid
	b_min, b_max = extrema(dd.bgrid)

	# Función objetivo en términos de b', dada vuelta 
	obj_f(bpv) = -eval_value(jb, jy, bpv, itp_q, itp_v, dd)[1]

	# Resuelve el máximo
	res = Optim.optimize(obj_f, b_min, b_max, GoldenSection())
	
	# Extrae el argmax
	b_star = res.minimizer
	
	# Extrae v y c consistentes con b'
	vp, c_star = eval_value(jb, jy, b_star, itp_q, itp_v, dd)
	
	return vp, c_star, b_star
end

function value_default(jb, jy, dd::Deuda)
	β, θ = (dd.pars[sym] for sym in (:β, :θ))
	""" Calcula el valor de estar en default en el estado (b,y) """
	yv = dd.ygrid[jy]
  
	# Consumo en default es el ingreso menos los costos de default
	c = defcost(yv, dd)

	# Valor de continuación tiene en cuenta la probabilidad θ de reacceder a mercados
	Ev = 0.0
	for jyp in eachindex(dd.ygrid)
		prob = dd.Py[jy, jyp]
		Ev += prob * ( θ * dd.v[jb, jyp] + (1-θ) * dd.vD[jb, jyp] )
	end

	v = u(c, dd) + β * Ev
	
	return c, v
end

function vfi_iter!(new_v, itp_q, dd::Deuda)
	# Reconstruye la interpolación de la función de valor
	knots = (dd.bgrid,dd.ygrid)
	itp_v = interpolate(knots, dd.v, Gridded(Linear()))

	for jb in eachindex(dd.bgrid), jy in eachindex(dd.ygrid)
		
		# En repago
		vp, c_star, b_star = opt_value(jb, jy, itp_q, itp_v, dd)

		# Guarda los valores para repago 
		dd.vR[jb, jy] = vp
		dd.gb[jb, jy] = b_star
		dd.gc[jb, jy, 1] = c_star
		
		# En default
		cD, vD = value_default(jb, jy, dd)
		dd.vD[jb, jy] = vD
		dd.gc[jb, jy, 2] = cD
	end
	
	χ, ℏ = (dd.pars[sym] for sym in (:χ, :ℏ))
	itp_vD = interpolate(knots, dd.vD, Gridded(Linear()))
	for (jb, bv) in enumerate(dd.bgrid), (jy, yv) in enumerate(dd.ygrid)
		# Valor de repagar y defaultear llegando a (b,y)
		vr = dd.vR[jb, jy]
		vd = itp_vD((1-ℏ)*bv, yv)
		
		# Probabilidad de default
		## Modo 1: valor extremo tipo X directo
		# pr = exp(vd / χ) / ( exp(vd / χ) + exp(vr / χ) )

		## Modo 2: valor extremo tipo X evitando comparar exponenciales de cosas grandes
		# lpr = vd / χ - logsumexp([vd/χ, vr/χ])
		# pr = exp(lpr)
		# if isnan(pr) || !(0 <= pr <= 1)
		# 	pr = ifelse(vd > vr, 1, 0)
		# end

		## Modo 3: evaluando una distribución en vd-vr
		pr = cdf(Normal(0, χ), vd-vr)

		# Guarda el valor y la probabilidad de default al llegar a (b,y)
		new_v[jb, jy] = pr * vd + (1-pr) * vr
		dd.prob[jb, jy] = pr
	end
end

function vfi!(dd::Deuda; tol::Float64 = 1e-8, maxiter = 2000, verbose = true)
	""" Itera sobre la ecuación de Bellman del país para encontrar la función de valor, probabilidad de default, consumo en repago y en default """
	new_v = similar(dd.v)

	dist = 1 + tol
	iter = 0

	# Interpolación del precio de la deuda
	knots = (dd.bgrid, dd.ygrid)
	itp_q = interpolate(knots, dd.q, Gridded(Linear()))

	# Loop principal sobre la Bellman del país
	while dist > tol && iter < maxiter
		iter += 1

		vfi_iter!(new_v, itp_q, dd)

		# Distancia entre la función de valor y el guess viejo 
		dist = norm(new_v - dd.v) / (1+norm(dd.v))

		# Actualiza la función de valor 
		dd.v .= new_v
	end
	verbose && print("Iteration $iter. Distance = $dist\n")
	dist < tol || print("✓")
end

function q_iter!(new_q, new_qd, dd::Deuda)
	""" Ecuación de Euler de los acreedores determinan el precio de la deuda dada la deuda, el ingreso, y el precio esperado de la deuda """
	ρ, κ, ℏ, θ, r = (dd.pars[sym] for sym in (:ρ, :κ, :ℏ, :θ, :r))

	# Interpola el precio de la deuda (para mañana)
	knots = (dd.bgrid, dd.ygrid)
	itp_qd = interpolate(knots, dd.qD, Gridded(Linear()))
	itp_q  = interpolate(knots, dd.q,  Gridded(Linear()))

	for (jbp, bpv) in enumerate(dd.bgrid), (jy, yv) in enumerate(dd.ygrid)
		Eq = 0.0
		EqD = 0.0
		for (jyp, ypv) in enumerate(dd.ygrid)
			prob_def = dd.prob[jbp, jyp]
			
			# Si el país tiene acceso a mercados, emite y puede hacer default mañana
			bpp = dd.gb[jbp, jyp]
			rep_R = (1-prob_def) * (κ + (1-ρ) * itp_q(bpp, ypv)) + prob_def * (1-ℏ) * itp_qd((1-ℏ)*bpv, ypv)
			
			# Si el país está en default, mañana puede recuperar acceso a mercados
			rep_D = θ * rep_R + (1-θ) * dd.qD[jbp, jyp]
			
			prob = dd.Py[jy, jyp]
			Eq += prob * rep_R
			EqD += prob * rep_D
		end
		new_q[jbp, jy]  = Eq / (1+r)
		new_qd[jbp, jy] = EqD / (1+r)
	end
end

function update_q!(dd::Deuda; tol = 1e-8, maxiter = 2000, verbose = false)
	""" Itera sobre la ecuación de Bellman de los acreedores para encontrar el precio de la deuda """
	new_q = copy(dd.q)
	new_qd = copy(dd.q)

	dist = 1+tol
	iter = 0
	while dist > tol && iter < maxiter
		iter += 1

		q_iter!(new_q, new_qd, dd)

		dist = norm(new_q - dd.q) / (1+norm(dd.q))

		dd.q .= new_q
		dd.qD .= new_qd
	end
	verbose && print(iter)
end

function eqm!(dd::Deuda; tol = 1e-8, maxiter = 250, verbose=false)
	""" Itera sobre la mejor respuesta del país y los acreedores hasta encontrar políticas de default y consumo óptimas dados precios de la deuda que reflejen la probabilidad de default """
	dist = 1+tol
	iter = 0

	tol_vfi = 1e-2

	while dist > tol && iter < maxiter
		iter += 1

		print("Iteration $iter: ")

		q_old = copy(dd.q)
		v_old = copy(dd.v)

		# Problema del país dados los precios de la deuda
		vfi!(dd, tol=tol_vfi, verbose = verbose)
		dist_v = norm(dd.v - v_old) / (1+norm(v_old))

		# Problema de los acreedores dada la probabilidad de default del país
		update_q!(dd, verbose = verbose)

		dist_q = norm(dd.q - q_old) / (1+norm(q_old))
		dist = max(dist_q, dist_v)

		tol_vfi = max(1e-8, tol_vfi * 0.75)
		print("dist = $dist\n")
	end
end

function mpe!(dd::Deuda; tol = 1e-8, maxiter = 500)
	new_v = similar(dd.v)
	new_q = similar(dd.q)
	new_qd = similar(dd.qD)

	dist = 1+tol
	iter = 0

	knots = (dd.bgrid, dd.ygrid)

	while dist > tol && iter < maxiter
		iter += 1

		print("Iteration $iter: ")

		# Actualiza el precio de la deuda
		q_iter!(new_q, new_qd, dd)
		dist_q = norm(new_q - dd.q) / max(1, norm(dd.q))
		
		# Interpolación del precio de la deuda
		itp_q = interpolate(knots, new_q, Gridded(Linear()))

		# Actualiza la función de valor
		vfi_iter!(new_v, itp_q, dd)
		dist_v = norm(new_v - dd.v) / max(1, norm(dd.v))

		# Distancias
		dist = max(dist_q, dist_v)

		# Guardamos todo
		dd.v .= new_v
		dd.q .= new_q
		dd.qD.= new_qd

		print("dist (v,q) = ($(round(dist_v, sigdigits=2)), $(round(dist_q, sigdigits=2)))\n")
	end
end

