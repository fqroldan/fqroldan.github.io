print("Loading income fluctuations problem…")

using PlotlyJS, LinearAlgebra, Interpolations, Optim, Distributions

using QuantEcon: tauchen

struct IFP
	β::Float64
	γ::Float64

	r::Float64

	kgrid::Vector{Float64}
	ygrid::Vector{Float64}
	Py::Matrix{Float64}

	v::Matrix{Float64}
	gc::Matrix{Float64}
	gk::Matrix{Float64}
end
function IFP(;β=0.96, r=0.02, γ=2, Nk = 20, Ny = 25, μy = 1, ρy = 0.8, σy = 0.02)
	kgrid = range(0,1,length=Nk)

	ychain = tauchen(Ny, ρy, σy, 0, 2)
	ygrid = exp.(ychain.state_values) * μy
	Py = ychain.p

	v = zeros(Nk, Ny)
	gc = zeros(Nk, Ny)
	gk = zeros(Nk, Ny)

	return IFP(β, γ, r, kgrid, ygrid, Py, v, gc, gk)
end

u(cv, ce::IFP) = u(cv, ce.γ)
function u(cv, γ)
	if γ == 1
		return log(cv)
	else
		return cv^(1-γ) / (1-γ)
	end
end

function budget_constraint(kpv, kv, yv, r)
	c = kv * (1+r) - kpv + yv
	return c
end

function eval_value(kpv, kv, yv, py, itp_v::AbstractInterpolation, ce::IFP)
	β, r = ce.β, ce.r

	cv = budget_constraint(kpv, kv, yv, r)

	cv > 0 || return cv, -Inf
	
	ut = u(cv, ce)

	Ev = 0.0
	for (jyp, ypv) in enumerate(ce.ygrid)
		prob = py[jyp]
		Ev += prob * itp_v(kpv, ypv)
	end
	
	v = ut + β * Ev

	return cv, v
end

function opt_value(jk, jy, itp_v::AbstractInterpolation, ce::IFP)
	kv = ce.kgrid[jk]
	yv = ce.ygrid[jy]
	
	k_min = minimum(ce.kgrid)
	k_max = maximum(ce.kgrid)
	k_max = min(k_max, max(0, kv * (1+ce.r) + yv - 1e-5))

	py = ce.Py[jy,:]

	obj_f(kpv) = -eval_value(kpv, kv, yv, py, itp_v, ce)[2]

	res = Optim.optimize(obj_f, k_min, k_max, GoldenSection())

	vp = -res.minimum
	k_star = res.minimizer
	c_star = budget_constraint(k_star, kv, yv, ce.r)

	return k_star, vp, c_star
end

function vfi_iter!(new_v, itp_v::AbstractInterpolation, ce::IFP)
	for jk in eachindex(ce.kgrid), jy in eachindex(ce.ygrid)
		
		k_star, vp, c_star = opt_value(jk, jy, itp_v, ce)

		new_v[jk, jy] = vp
		ce.gc[jk, jy] = c_star
		ce.gk[jk, jy] = k_star
	end
end

function vfi!(ce::IFP; tol = 1e-8, maxiter = 2000, verbose = true)
	new_v = similar(ce.v)
	knots = (ce.kgrid, ce.ygrid)
	
	dist = 1+tol
	iter = 0

	while dist > tol && iter < maxiter
		iter += 1
		
		itp_v = interpolate(knots, ce.v, Gridded(Linear()))
		vfi_iter!(new_v, itp_v, ce)

		dist = norm(new_v - ce.v) / norm(ce.v)

		ce.v .= new_v
	end
	verbose && print("Iteration $iter. Distance = $dist\n")
	dist < tol || print("✓")
end

print(" ✓\nConstructor ce = IFP(;β=0.96, r=0.02, γ=2, Nk = 20, Ny = 25, μy = 1, ρy = 0.8, σy = 0.02)\n")
print("Solver vfi!(ce::IFP; tol = 1e-8, maxiter = 2000, verbose = true)\n")