using QuantEcon, Optim, Interpolations, Printf, LinearAlgebra, PlotlyJS, ColorSchemes, Distributions

abstract type SOE
end

mutable struct SOEwr <: SOE
	β::Float64
	γ::Float64
	r::Float64

	ϖN::Float64
	ϖT::Float64
	η::Float64

	α::Float64
	wbar::Float64

	agrid::Vector{Float64}
	zgrid::Vector{Float64}
	Pz::Matrix{Float64}

	v::Dict{Symbol, Array{Float64, 3}}
	
	pN::Array{Float64, 2}
	w::Array{Float64, 2}
	Ap::Array{Float64, 2}
	Y::Array{Float64, 2}
end

function SOEwr(; β = 0.97, γ = 2, r = 0.02, ϖN = 0.55, η = 1/0.83-1, α = 0.67, wbar = 0.8, ρz = 0.945, σz = 0.025, Na = 40, Nz = 21, amin = -0.5, amax = 10)

	ϖT = 1 - ϖN

	agrid = cdf.(Beta(2,1), range(0,1, length=Na))
	agrid = amin .+ (amax-amin)*agrid

	zchain = tauchen(Nz, ρz, σz, 0, 3)
	zgrid = exp.(zchain.state_values)
	Pz = zchain.p

	v = Dict(key => ones(Na, Na, Nz) for key in [:v, :c, :a])

	pN = ones(Na, Nz)
	w = ones(Na, Nz)
	Ap = [av for av in agrid, zv in zgrid]
	Y  = [exp(zv) for av in agrid, zv in zgrid]

	return SOEwr(β, γ, r, ϖN, ϖT, η, α, wbar, agrid, zgrid, Pz, v, pN, w, Ap, Y)
end

price_index(pN, sw::SOE) = price_index(pN, 1, sw)
function price_index(pN, pT, sw::SOE)
	ϖN, ϖT, η = sw.ϖN, sw.ϖT, sw.η
	return (ϖN^(1/(1+η)) * pN^(η/(1+η)) + ϖT^(1/(1+η)) * pT^(η/(1+η)))^((1+η)/η)
end

function utility(c, sw::SOE)
	γ = sw.γ
	cmin = 1e-3
	if c < cmin
		return utility(cmin,sw) + (c-cmin) * (cmin)^-γ
	else
		γ == 1 && return log(c)
		return c^(1-γ)/(1-γ)
	end
end

function expect_v(apv, Apv, pz, itp_v, sw::SOE)
	Ev = 0.0
	for (jzp, zpv) in enumerate(sw.zgrid)
		prob = pz[jzp]
		Ev += prob * itp_v[:v](apv, Apv, zpv)
	end
	return Ev
end

budget_constraint(apv, av, yv, r, pCv) = ( yv + av - apv/(1+r) ) / pCv

function eval_value(apv, av, yv, Apv, pz, pCv, itp_v, sw::SOE)
	c = budget_constraint(apv, av, yv, sw.r, pCv)
	u = utility(c, sw)

	Ev = expect_v(apv, Apv, pz, itp_v, sw)

	return u + sw.β * Ev
end

function optim_value(av, yv, Apv, pz, pCv, itp_v, sw::SOE)

	obj_f(x) = -eval_value(x, av, yv, Apv, pz, pCv, itp_v, sw)
	amin, amax = extrema(sw.agrid)

	res = Optim.optimize(obj_f, amin, amax)

	apv = res.minimizer
	v  = -res.minimum

	c = budget_constraint(apv, av, yv, sw.r, pCv)

	return v, apv, c
end

function vf_iter!(new_v, sw::SOE)
	itp_v = Dict(key => interpolate((sw.agrid, sw.agrid, sw.zgrid), sw.v[key], Gridded(Linear())) for key in keys(sw.v))

	for (jA, Av) in enumerate(sw.agrid), (jz, zv) in enumerate(sw.zgrid)
		pNv = sw.pN[jA, jz]
		pCv = price_index(pNv, sw)

		Apv = sw.Ap[jA, jz]
		yv = sw.Y[jA, jz]

		pz = sw.Pz[jz, :]

		for (ja, av) in enumerate(sw.agrid)
			v, apv, c = optim_value(av, yv, Apv, pz, pCv, itp_v, sw)

			new_v[:v][ja, jA, jz] = v
			new_v[:a][ja, jA, jz] = apv
			new_v[:c][ja, jA, jz] = c
		end
	end
end

function update_v!(new_v, sw::SOE; upd_η = 1)
	for key in keys(new_v)
		sw.v[key] = sw.v[key] + upd_η * (new_v[key] - sw.v[key])
	end
end

function vfi!(sw::SOE; tol=1e-4, maxiter = 2000)
	iter, dist = 0, 1+tol
	new_v = Dict(key => similar(val) for (key, val) in sw.v)

	while iter < maxiter && dist > tol
		iter += 1
		
		vf_iter!(new_v, sw)

		dist = maximum([ norm(new_v[key] - sw.v[key]) / (1+norm(sw.v[key])) for key in keys(sw.v) ])

		norm_v = 1+maximum([norm(sw.v[key]) for key in keys(sw.v)])

		print("Iteration $iter: dist = $(@sprintf("%0.3g", dist)) at ‖v‖ = $(@sprintf("%0.3g", norm_v))\n")

		update_v!(new_v, sw)
	end
	return dist
end

function labor_demand(zv, cT, w, sw::SOE)
	α, ϖN, ϖT, η = sw.α, sw.ϖN, sw.ϖT, sw.η

	hN = (α/w * ϖN / ϖT)^(1/(1+α*η)) * cT^(1+η)
	hT = (zv*α/w)^(1/(1-α))

	return (h = hN+hT, hN = hN, hT = hT)
end

function find_w(zv, cT, wbar, sw::SOE)
	hN = labor_demand(zv, cT, wbar, sw).hN
	hT = labor_demand(zv, cT, wbar, sw).hT
	H = hN + hT

	if H < 1
		wopt = wbar
	else
		f(w) = (labor_demand(zv, cT, w, sw).h - 1)^2
		res = Optim.optimize(f, wbar, 2*wbar)
		wopt = res.minimizer
		hN = labor_demand(zv, cT, wopt, sw).hN
		hT = labor_demand(zv, cT, wopt, sw).hT
	end

	return hN, hT, wopt
end

function diff_pN(pNv, pcC, zv, sw::SOE)
	α, ϖN, ϖT, η, wbar = sw.α, sw.ϖN, sw.ϖT, sw.η, sw.wbar

	pCv = price_index(pNv, sw)
	C = pcC / pCv

	cT = C * ϖT * (pCv)^η      # cᵢ = ϖᵢ (pᵢ/p)^(-η) C

	hN, hT, wopt = find_w(zv, cT, wbar, sw)

	yN = hN^α
	yT = zv * hT^α

	pN_new = ϖN / ϖT * (cT/yN)^(1+η)

	output = pN_new * yN + yT

	return (F = (pN_new-pNv)^2, y = output, w = wopt)
end

function iter_pN!(new_p, sw::SOE; upd_η = 1)
	minp = 0.9 * minimum(sw.pN)
	maxp = 1.1 * maximum(sw.pN)
	for (jA, Av) in enumerate(sw.agrid), (jz, zv) in enumerate(sw.zgrid)
		pNg = sw.pN[jA, jz]
		pcC = sw.v[:c][jA, jA, jz] * price_index(pNg, sw)
		obj_f(x) = diff_pN(x, pcC, zv, sw).F

		res = Optim.optimize(obj_f, minp, maxp)

		p = sw.pN[jA, jz] * (1-upd_η) + res.minimizer * upd_η
		new_p[jA, jz] = p
		
		others = diff_pN(p, pcC, zv, sw)
		sw.Y[jA, jz] = others.y
		sw.w[jA, jz] = others.w
	end
end

function iter_LoM!(sw::SOE; upd_η = 1)
	for jA in eachindex(sw.agrid), jz in eachindex(sw.zgrid)
		sw.Ap[jA, jz] = (1-upd_η) * sw.Ap[jA, jz] + upd_η * sw.v[:a][jA, jA, jz]
	end
end

function update_eqm!(new_p, sw::SOE; upd_η = 1)
	iter_pN!(new_p, sw)
	iter_LoM!(sw)
	dist = norm(new_p - sw.pN)
	sw.pN = sw.pN + upd_η * (new_p - sw.pN)
	return dist
end

function comp_eqm!(sw::SOE; tol = 1e-3, maxiter = 2000)
	iter, dist = 0, 1+tol
	new_p = similar(sw.pN)
	tol_vfi = 1e-2

	while dist > tol && iter < maxiter
		iter += 1
		print("Outer Iteration $iter (tol = $(@sprintf("%0.3g",tol_vfi)))\n")
		dist_v = vfi!(sw, tol = tol_vfi)

		norm_p = norm(sw.pN)
		dist_p = update_eqm!(new_p, sw) / (1+norm_p)

		dist = max(dist_p, 10*dist_v)

		print("After $iter iterations, dist = $(@sprintf("%0.3g",dist_p)) at ‖pN‖ = $(@sprintf("%0.3g", norm_p))\n\n")

		tol_vfi = max(1e-4, tol_vfi * 0.9)
	end
end

function plot_cons(sw::SOE; indiv=false)

	jA = 5
	jz = 5

	cons_mat = [sw.v[:c][ja, jA, jz] for ja in eachindex(sw.agrid), jA in eachindex(sw.agrid)]
	cons_agg = [sw.v[:c][ja, ja, jz] for ja in eachindex(sw.agrid)]

	Na = length(sw.agrid)
	colvec = [get(ColorSchemes.davos, (jA-1)/(Na-1)) for jA in eachindex(sw.agrid)]

	scats = [scatter(x=sw.agrid, y=cons_mat[:, jA], marker_color=colvec[jA], name = "A = $(@sprintf("%0.3g",Av))") for (jA, Av) in enumerate(sw.agrid)]
	if !indiv
		push!(scats, scatter(x=sw.agrid, y=cons_agg, line_dash="dash", line_width=3, name="Agregado", line_color="#710627"))
	end

	layout = Layout(title="Consumo",
		font_family = "Lato", font_size = 18, width = 1920*0.5, height=1080*0.5,
		paper_bgcolor="#1e1e1e", plot_bgcolor="#1e1e1e", font_color="white",
		xaxis = attr(zeroline = false, gridcolor="#353535", title="<i>a"),
		yaxis = attr(zeroline = false, gridcolor="#353535"),
		)

	plot(scats, layout)
end

function plot_wage(sw::SOE)

	con = contour(x=sw.agrid, y=sw.zgrid,
		z = sw.w)

	layout = Layout(title="Salario",
		font_family = "Lato", font_size = 18, width = 1920*0.5, height=1080*0.5,
		paper_bgcolor="#1e1e1e", plot_bgcolor="#1e1e1e", font_color="white",
		xaxis = attr(zeroline = false, gridcolor="#353535", title="<i>A"),
		yaxis = attr(zeroline = false, gridcolor="#353535", title="<i>z"),
		)

	plot(con, layout)
end

function iter_simul!(tt, path, itp_v, itp_eq, At, zt, sw)
	w  = itp_eq[:w](At, zt)
	Y  = itp_eq[:Y](At, zt)
	pN = itp_eq[:pN](At, zt)
	pC = price_index(pN, sw)

	C = itp_v[:c](At, At, zt)

	cT = C * sw.ϖT * (pC)^sw.η
	cN = C * sw.ϖN * (pC/pN)^sw.η

	CA = pC * Y - pC * C

	path[:CA][tt] = CA
	path[:pN][tt] = pN
	path[:w][tt]  = w
	path[:Y][tt]  = Y
	path[:C][tt]  = C
	path[:A][tt]  = At
	path[:z][tt]  = zt

	A_new = itp_v[:a](At, At, zt)

	amin, amax = extrema(sw.agrid)
	A_new = max(amin, min(amax, A_new))

	ρz, σz = 0.945, 0.025
	ϵ_new = rand(Normal(0,1))
	z_new = exp(ρz * log(zt) + σz * ϵ_new)

	zmin, zmax = extrema(sw.zgrid)
	z_new = max(zmin, min(zmax, z_new))	

	return A_new, z_new
end

function eq(key, sw::SOE)
	if key == :pN
		return sw.pN
	elseif key == :w
		return sw.w
	elseif key == :Y
		return sw.Y
	end
end

function simul(sw::SOE; T = 100)
	path = Dict(key => zeros(T) for key in [:w, :Y, :CA, :C, :pN, :A, :z])
	itp_v = Dict(key => interpolate((sw.agrid, sw.agrid, sw.zgrid), sw.v[key], Gridded(Linear())) for key in keys(sw.v));

	itp_eq = Dict(key => interpolate((sw.agrid, sw.zgrid), eq(key, sw), Gridded(Linear())) for key in [:pN, :Y, :w])

	A0 = 0.0
	z0 = 1.0
	for tt in 1:T
		A0, z0 = iter_simul!(tt, path, itp_v, itp_eq, A0, z0, sw)
	end
	return path
end