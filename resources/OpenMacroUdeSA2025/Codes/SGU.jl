using Optim, Interpolations, Printf, LinearAlgebra, PlotlyJS, ColorSchemes, Distributions
using QuantEcon: tauchen

print("Economía pequeña y abierta con rigideces de salario. Inspirado por Schmitt-Grohé y Uribe (2016)\n")
print("Cargando códigos…")

abstract type SOE
end

struct SOEwr <: SOE
	pars::Dict{Symbol, Float64}

	agrid::Vector{Float64}
	zgrid::Vector{Float64}
	Pz::Matrix{Float64}

	v::Array{Float64, 3}
	gc::Array{Float64, 3}
	ga::Array{Float64, 3}
	
	pN::Array{Float64, 2}
	w::Array{Float64, 2}
	Ap::Array{Float64, 2}
	Y::Array{Float64, 2}
end

function SOEwr(; β = 0.97, γ = 2, r = 0.02, ϖN = 0.55, η = 1/0.83-1, α = 0.67, wbar = 0.35, ρz = 0.945, σz = 0.025, Na = 40, Nz = 21, amin = -1, amax = 4)

	ϖT = 1 - ϖN

	pars = Dict(:β=>β, :γ=>γ, :r=>r, :ϖN=>ϖN, :ϖT=>ϖT, :η=>η, :α=>α, :wbar=>wbar, :ρz => ρz, :σz => σz)

	# agrid = cdf.(Beta(2,1), range(0,1, length=Na))
	# agrid = amin .+ (amax-amin)*agrid
	agrid = range(amin, amax, length=Na)

	zchain = tauchen(Nz, ρz, σz, 0, 3)
	zgrid = exp.(zchain.state_values)
	Pz = zchain.p

	v = ones(Na, Na, Nz)
	gc = ones(Na, Na, Nz)
	ga = ones(Na, Na, Nz)

	pN = ones(Na, Nz)
	w = ones(Na, Nz)
	Ap = [Av for Av in agrid, zv in zgrid]
	Y  = [zv for av in agrid, zv in zgrid]

	return SOEwr(pars, agrid, zgrid, Pz, v, gc, ga, pN, w, Ap, Y)
end

price_index(pN, sw::SOE) = price_index(pN, 1, sw)
function price_index(pN, pT, sw::SOE)
	ϖN, ϖT, η = (sw.pars[sym] for sym in (:ϖN, :ϖT, :η))
	return (ϖN^(1/(1+η)) * pN^(η/(1+η)) + ϖT^(1/(1+η)) * pT^(η/(1+η)))^((1+η)/η)
end

function utility(c, sw::SOE)
	γ = sw.pars[:γ]
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
		Ev += prob * itp_v(apv, Apv, zpv)
	end
	return Ev
end

budget_constraint(apv, av, yv, r, pCv) = ( yv + av - apv/(1+r) ) / pCv

function eval_value(apv, av, yv, Apv, pz, pCv, itp_v, sw::SOE)
	β, r = (sw.pars[key] for key in (:β, :r))

	c = budget_constraint(apv, av, yv, r, pCv)
	u = utility(c, sw)

	Ev = expect_v(apv, Apv, pz, itp_v, sw)

	return u + β * Ev
end

function optim_value(av, yv, Apv, pz, pCv, itp_v, sw::SOE)

	obj_f(x) = eval_value(x, av, yv, Apv, pz, pCv, itp_v, sw)
	amin, amax = extrema(sw.agrid)

	res = Optim.maximize(obj_f, amin, amax)

	apv = Optim.maximizer(res)
	v  = Optim.maximum(res)

	c = budget_constraint(apv, av, yv, sw.pars[:r], pCv)

	return v, apv, c
end

function vf_iter!(new_v, sw::SOE)
	itp_v = interpolate((sw.agrid, sw.agrid, sw.zgrid), sw.v, Gridded(Linear()))

    for jA in eachindex(sw.agrid), jz in eachindex(sw.zgrid)
		pNv = sw.pN[jA, jz]
		pCv = price_index(pNv, sw)

		Apv = sw.Ap[jA, jz]
		yv = sw.Y[jA, jz]

		pz = sw.Pz[jz, :]

		for (ja, av) in enumerate(sw.agrid)
			v, apv, c = optim_value(av, yv, Apv, pz, pCv, itp_v, sw)

			new_v[ja, jA, jz] = v
			sw.ga[ja, jA, jz] = apv
			sw.gc[ja, jA, jz] = c
		end
	end
end

function vfi!(sw::SOE; tol=1e-6, maxiter = 2000)
	iter, dist = 0, 1+tol
	new_v = similar(sw.v)

	upd_η = 1
	while iter < maxiter && dist > tol
		iter += 1
		
		vf_iter!(new_v, sw)

		dist = norm(new_v - sw.v) / max(1,norm(sw.v))

		norm_v = norm(sw.v)

		print("Iteration $iter: dist = $(@sprintf("%.3g",dist)) at ‖v‖ = $(@sprintf("%.3g",norm_v))\n")

		sw.v .= sw.v + upd_η * (new_v - sw.v)
	end
	return dist
end

# function labor_demand(zv, cT, w, sw::SOE) # para dos bienes
# 	α, ϖN, ϖT, η = (sw.pars[sym] for sym in (:α, :ϖN, :ϖT, :η))

# 	hN = (α/w * ϖN / ϖT)^(1/(1+α*η)) * cT^(1+η)
# 	hT = (zv*α/w)^(1/(1-α))

# 	return hN, hT
# end

# function find_w(zv, cT, wbar, sw::SOE)
# 	hN, hT = labor_demand(zv, cT, wbar, sw) 
# 	H = hN + hT

# 	if H < 1
# 		weqm = wbar
# 	else
# 		f(w) = (sum(labor_demand(zv, cT, w, sw)) - 1)^2
		
#         res = Optim.optimize(f, wbar, max(2*wbar, 5))
		
#         weqm = res.minimizer
# 		hN, hT = labor_demand(zv, cT, weqm, sw) 
# 	end
    
#     α = sw.pars[:α]    
#     yN = hN^α
#     yT = zv * hT^α

# 	return yN, yT, weqm
# end

function eq_h(sw::SOE, cT)
    # Computes labor supply consistent with consumption of tradables
    Ls = 1

    h = H(cT, sw.pars[:wbar], sw)
    L = min(h, Ls)
    return L
end

function H(cT, w, sw::SOE)
    ϖN, ϖT , α, η = (sw.pars[sym] for sym in (:ϖN, :ϖT, :α, :η))
	H = (α/w * ϖN / ϖT)^(1/(1+α*η)) * cT^(1+η)
end

function find_w(cT, wbar, sw)

	h_const = H(cT, wbar, sw)

	if h_const <= 1
		weqm = wbar
	else
		f(w) = (H(cT, w, sw) - 1)^2

		res = Optim.optimize(f, wbar, max(2*wbar, 5))
		
		weqm = res.minimizer
	end

	h = H(cT, weqm, sw)

	α = sw.pars[:α]
	yN = h^α
	
	return yN, weqm
end

function diff_pN(pNv, C, yT, sw::SOE)
	α, ϖN, ϖT, η, wbar = (sw.pars[sym] for sym in (:α, :ϖN, :ϖT, :η, :wbar))

	pCv = price_index(pNv, sw)

	cT = C * ϖT * (pCv)^η      # cᵢ = ϖᵢ (pᵢ/p)^(-η) C

	yN, weqm = find_w(cT, wbar, sw)

    output = pNv * yN + yT

	pN_new = ϖN / ϖT * (cT/yN)^(1+η)

	return (pN_new - pNv)^2, output, weqm
end

function iter_pN!(new_p, sw::SOE; upd_η = 1)
	minp = 0.9 * minimum(sw.pN)
	maxp = 1.1 * maximum(sw.pN)
	for (jA, Av) in enumerate(sw.agrid), (jz, zv) in enumerate(sw.zgrid)
		C = sw.gc[jA, jA, jz]

		yT = zv
		obj_f(x) = diff_pN(x, C, yT, sw)[1]

		res = Optim.optimize(obj_f, minp, maxp)

		p = sw.pN[jA, jz] * (1-upd_η) + res.minimizer * upd_η
		new_p[jA, jz] = p
		
		_, y, w = diff_pN(p, C, yT, sw)
		sw.Y[jA, jz] = y
		sw.w[jA, jz] = w
	end
end

function iter_LoM!(sw::SOE; upd_η = 1)
	for jA in eachindex(sw.agrid), jz in eachindex(sw.zgrid)
		sw.Ap[jA, jz] = (1-upd_η) * sw.Ap[jA, jz] + upd_η * sw.ga[jA, jA, jz]
	end
end

function update_eqm!(new_p, sw::SOE; upd_η = 1)
	iter_pN!(new_p, sw)
	iter_LoM!(sw)
	dist = norm(new_p - sw.pN)
	sw.pN .= sw.pN + upd_η * (new_p - sw.pN)
	return dist
end

function comp_eqm!(sw::SOE; tol = 1e-4, maxiter = 2000)
	iter, dist = 0, 1+tol
	new_p = similar(sw.pN)
	tol_vfi = 0.05

	while dist > tol && iter < maxiter
		iter += 1
		print("Outer Iteration $iter (inner tol = $(@sprintf("%.3g",tol_vfi)))\n")
		dist_v = vfi!(sw, tol = tol_vfi)

		norm_p = norm(sw.pN)
		dist_p = update_eqm!(new_p, sw) / max(1,norm_p)

		dist = max(dist_p, dist_v)

		print("After $iter iterations, dist = $(@sprintf("%.3g",dist_p)) at ‖pN‖ = $(@sprintf("%.3g",norm_p))\n\n")

		tol_vfi = min(dist / 2, tol_vfi * 0.9)
        tol_vfi = max(tol, tol_vfi)
	end
end

include("simulSOE.jl")

print(" ✓\n")
print("Constructor sw = SOEwr(; β = 0.97, γ = 2, r = 0.02, ϖN = 0.55, η = 1/0.83-1, α = 0.67, wbar = 0.8, ρz = 0.945, σz = 0.025, Na = 40, Nz = 21, amin = -0.5, amax = 10)\n")
print("Loop: comp_eqm!(sw; tol = 1e-3, maxiter = 2000)")
