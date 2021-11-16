using Optim, Interpolations, Printf, LinearAlgebra, PlotlyJS, ColorSchemes, Distributions
using QuantEcon: tauchen

abstract type SOE
end

struct CC <: SOE
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

	v::Array{Float64, 4}
	gc::Array{Float64, 4}
	ga::Array{Float64, 4}
	
	pN::Array{Float64, 3}
	w::Array{Float64, 3}
	Ap::Array{Float64, 3}
	Y::Array{Float64, 3}
end

function CC(; β = 0.97, γ = 2, r = 0.02, ϖN = 0.55, η = 1/0.83-1, α = 0.67, wbar = 0.8, ρz = 0.945, σz = 0.025, Na = 20, Nz = 11, amin = -0.5, amax = 10)

	ϖT = 1 - ϖN

	agrid = cdf.(Beta(2,1), range(0,1, length=Na))
	agrid = amin .+ (amax-amin)*agrid

	zchain = tauchen(Nz, ρz, σz, 0, 3)
	zgrid = exp.(zchain.state_values)
	Pz = zchain.p

	v = ones(Na, Na, Nz, Nz)
	gc = ones(Na, Na, Nz, Nz)
	ga = ones(Na, Na, Nz, Nz)

	pN = ones(Na, Nz, Nz)
	w = ones(Na, Nz, Nz)
	Ap = [av for av in agrid, zv in zgrid, zv in zgrid]
	Y  = [exp(zv) for av in agrid, zv in zgrid, zv in zgrid]

	return CC(β, γ, r, ϖN, ϖT, η, α, wbar, agrid, zgrid, Pz, v, gc, ga, pN, w, Ap, Y)
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

function expect_v(apv, Apv, ξv, pξ, itp_v, sw::SOE)
	Ev = 0.0
	for (jξp, ξpv) in enumerate(sw.zgrid)
		prob = pξ[jξp]
		Ev += prob * itp_v(apv, Apv, ξv, ξpv)
	end
	return Ev
end

budget_constraint(apv, av, yv, r, pCv) = ( yv + av - apv/(1+r) ) / pCv

function eval_value(apv, av, yv, Apv, ξv, pξ, pCv, itp_v, sw::SOE)
	c = budget_constraint(apv, av, yv, sw.r, pCv)
	u = utility(c, sw)

	Ev = expect_v(apv, Apv, ξv, pξ, itp_v, sw)

	return u + sw.β * Ev
end

function optim_value(av, yv, Apv, ξv, pξ, pCv, itp_v, sw::SOE)

	obj_f(x) = -eval_value(x, av, yv, Apv, ξv, pξ, pCv, itp_v, sw)
	amin, amax = extrema(sw.agrid)

	res = Optim.optimize(obj_f, amin, amax)

	apv = res.minimizer
	v  = -res.minimum

	c = budget_constraint(apv, av, yv, sw.r, pCv)

	return v, apv, c
end

function vf_iter!(new_v, sw::CC)
	itp_v = interpolate((sw.agrid, sw.agrid, sw.zgrid, sw.zgrid), sw.v, Gridded(Linear()))

	for jA in eachindex(sw.agrid), jz in eachindex(sw.zgrid), (jξ, ξv) in enumerate(sw.zgrid)
		pNv = sw.pN[jA, jz, jξ]
		pCv = price_index(pNv, sw)

		Apv = sw.Ap[jA, jz, jξ]
		yv = sw.Y[jA, jz, jξ]

		pξ = sw.Pz[jξ, :]

		for (ja, av) in enumerate(sw.agrid)
			v, apv, c = optim_value(av, yv, Apv, ξv, pξ, pCv, itp_v, sw)

			new_v[ja, jA, jz, jξ] = v
			sw.ga[ja, jA, jz, jξ] = apv
			sw.gc[ja, jA, jz, jξ] = c
		end
	end
end

function vfi!(sw::SOE; tol=1e-4, maxiter = 2000)
	iter, dist = 0, 1+tol
	new_v = similar(sw.v)

	upd_η = 1
	while iter < maxiter && dist > tol
		iter += 1
		
		vf_iter!(new_v, sw)

		dist = norm(new_v - sw.v) / (1+norm(sw.v))

		norm_v = norm(sw.v)

		print("Iteration $iter: dist = $(@sprintf("%0.3g", dist)) at ‖v‖ = $(@sprintf("%0.3g", norm_v))\n")

		sw.v .= sw.v + upd_η * (new_v - sw.v)
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
	for jA in eachindex(sw.agrid), (jz, zv) in enumerate(sw.zgrid), jξ in eachindex(sw.zgrid)
		pNg = sw.pN[jA, jz, jξ]
		pcC = sw.gc[jA, jA, jz, jξ] * price_index(pNg, sw)
		obj_f(x) = diff_pN(x, pcC, zv, sw).F

		res = Optim.optimize(obj_f, minp, maxp)

		p = sw.pN[jA, jz, jξ] * (1-upd_η) + res.minimizer * upd_η
		new_p[jA, jz, jξ] = p
		
		others = diff_pN(p, pcC, zv, sw)
		sw.Y[jA, jz, jξ] = others.y
		sw.w[jA, jz, jξ] = others.w
	end
end

function iter_LoM!(sw::SOE; upd_η = 1)
	for jA in eachindex(sw.agrid), jz in eachindex(sw.zgrid), jξ in eachindex(sw.zgrid)
		sw.Ap[jA, jz, jξ] = (1-upd_η) * sw.Ap[jA, jz, jξ] + upd_η * sw.ga[jA, jA, jz, jξ]
	end
end

function update_eqm!(new_p, sw::SOE; upd_η = 1)
	iter_pN!(new_p, sw)
	iter_LoM!(sw)
	dist = norm(new_p - sw.pN)
	sw.pN .= sw.pN + upd_η * (new_p - sw.pN)
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

function iter_simul!(tt, path, itp_gc, itp_ga, itp_w, itp_Y, itp_pN, At, zt, ξt, sw::SOE)
	w  = itp_w(At, zt, ξt)
	Y  = itp_Y(At, zt, ξt)
	pN = itp_pN(At, zt, ξt)
	pC = price_index(pN, sw)

	C = itp_gc(At, At, zt, ξt)

	cT = C * sw.ϖT * (pC)^sw.η
	cN = C * sw.ϖN * (pC/pN)^sw.η

	CA = pC * (Y - C)

	path[:CA][tt] = CA
	path[:pN][tt] = pN
	path[:w][tt]  = w
	path[:Y][tt]  = Y
	path[:C][tt]  = C
	path[:A][tt]  = At
	path[:z][tt]  = zt
	path[:ξ][tt]  = ξt

	A_new = itp_ga(At, At, zt, ξt)

	amin, amax = extrema(sw.agrid)
	A_new = max(amin, min(amax, A_new))

	ρz, σz = 0.945, 0.025
	ϵ_new = rand(Normal(0,1))
	ξ_new = exp(ρz * log(ξt) + σz * ϵ_new)

	zmin, zmax = extrema(sw.zgrid)
	ξ_new = max(zmin, min(zmax, ξ_new))	

	return A_new, ξt, ξ_new
end

function simul(sw::SOE; T = 100)
	path = Dict(key => zeros(T) for key in [:w, :Y, :CA, :C, :pN, :A, :z, :ξ])
	itp_gc = interpolate((sw.agrid, sw.agrid, sw.zgrid, sw.zgrid), sw.gc, Gridded(Linear()))
    itp_ga = interpolate((sw.agrid, sw.agrid, sw.zgrid, sw.zgrid), sw.ga, Gridded(Linear()))

	itp_w = interpolate((sw.agrid, sw.zgrid, sw.zgrid), sw.w, Gridded(Linear()))
    itp_Y = interpolate((sw.agrid, sw.zgrid, sw.zgrid), sw.Y, Gridded(Linear()))
    itp_pN = interpolate((sw.agrid, sw.zgrid, sw.zgrid), sw.pN, Gridded(Linear()))

	A0 = 0.0
	z0 = 1.0
	ξ0 = 1.0
	for tt in 1:T
		A0, z0, ξ0 = iter_simul!(tt, path, itp_gc, itp_ga, itp_w, itp_Y, itp_pN, A0, z0, ξ0, sw)
	end
	return path
end

function plot_cons(cc::CC)

	ja = floor(Int, length(cc.agrid)*0.6)
	jξ = ceil(Int, length(cc.zgrid)*0.5)
	jz = ceil(Int, length(cc.zgrid)*0.5)
	
	cons_z = [cc.gc[ja, ja, jz, jξ] for jz in eachindex(cc.zgrid)]
	CA_z   = 100 * [(cc.Y[ja, jz, jξ] - cons_z[jz]) / cc.Y[ja, jz, jξ] for jz in eachindex(cc.zgrid)]
	
	cons_ξ = [cc.gc[ja, ja, jz, jξ] for jξ in eachindex(cc.zgrid)]
	CA_ξ   = 100 * [(cc.Y[ja, jz, jξ] - cons_ξ[jξ]) / cc.Y[ja, jz, jξ] for jξ in eachindex(cc.zgrid)]
	
	# CA_ξ = [cc.Y[ja, jz, jξ] for jξ in eachindex(cc.zgrid)]
	# CA_z = [cc.Y[ja, jz, jξ] for jz in eachindex(cc.zgrid)]

	col_z = get(ColorSchemes.oslo, 0.5)
	col_ξ = get(ColorSchemes.oslo, 1)

	sc1 = scatter(x=cc.zgrid, y = CA_z, name = "z", yaxis = "y2", marker_color = col_z, legendgroup=1)
	sc2 = scatter(x=cc.zgrid, y = CA_ξ, name = "ξ", yaxis = "y2", marker_color = col_ξ, legendgroup=2)

	sc3 = scatter(x=cc.zgrid, y = cons_z, name = "z", yaxis = "y1", marker_color = col_z, legendgroup=1, showlegend=false)
	sc4 = scatter(x=cc.zgrid, y = cons_ξ, name = "ξ", yaxis = "y1", marker_color = col_ξ, showlegend=false, legendgroup=2)

	[plot([sc1, sc2]); plot([sc3, sc4])]

	annots = [
		attr(text = "Consumo", x=0.5, xanchor="center", xref="paper", y=0.45, yanchor="bottom", yref="paper", showarrow=false)
		attr(text = "Cuenta Corriente", x=0.5, xanchor="center", xref="paper", y=1, yanchor="top", yref="paper", showarrow=false)
	]

	layout = Layout(title="Productividad y Noticias", annotations = annots,
		font_family = "Lato", font_size = 18, width = 1920*0.5, height=1080*0.5,
		paper_bgcolor="#1e1e1e", plot_bgcolor="#1e1e1e", font_color="white",
		xaxis = attr(domain = [0.025, 0.975], zeroline = false, gridcolor="#353535", title="<i>z", anchor="y1"),
		yaxis = attr(zeroline = false, gridcolor="#353535", domain = [0, 0.45]),
		yaxis2 = attr(domain = [0.55, 1], title="% del PBI"),
		legend = attr(orientation="h")
	)

	plot([sc1, sc2, sc3, sc4], layout)
end
