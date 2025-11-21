using Optim, Interpolations, Printf, LinearAlgebra, PlotlyJS, ColorSchemes, Distributions
using QuantEcon: tauchen

include("SGU.jl")

struct SOEpl <: SOE
    pars::Dict{Symbol,Float64}

    agrid::Vector{Float64}
    zgrid::Vector{Float64}
    Pz::Matrix{Float64}

    v::Array{Float64,2}
    gc::Array{Float64,2}
    ga::Array{Float64,2}

    pN::Array{Float64,2}
    w::Array{Float64,2}
    Y::Array{Float64,2}
end

function SOEpl(; β = 0.97, γ = 2, r = 0.02, ϖN = 0.55, η = 1 / 0.83 - 1, κ = 0.35,α = 0.67, wbar = 0.8, ρz = 0.945, σz = 0.025, Na = 40, Nz = 21, amin = -1, amax = 4)

    ϖT = 1 - ϖN

    pars = Dict(:β => β, :γ => γ, :r => r, :ϖN => ϖN, :ϖT => ϖT, :η => η, :α => α, :κ => κ, :wbar => wbar)

    agrid = cdf.(Beta(2, 1), range(0, 1, length = Na))
    agrid = amin .+ (amax - amin) * agrid

    zchain = tauchen(Nz, ρz, σz, 0, 3)
    zgrid = exp.(zchain.state_values)
    Pz = zchain.p

    v = ones(Na, Nz)
    gc = ones(Na, Nz)
    ga = ones(Na, Nz)

    pN = ones(Na, Nz)
    w = ones(Na, Nz)
    Y = [exp(zv) for av in agrid, zv in zgrid]

    return SOEpl(pars, agrid, zgrid, Pz, v, gc, ga, pN, w, Y)
end

function expect_v(apv, pz, itp_v, sw::SOEpl)
    Ev = 0.0
    for (jzp, zpv) in enumerate(sw.zgrid)
        prob = pz[jzp]
        Ev += prob * itp_v(apv, zpv)
    end
    return Ev
end

budget_constraint_T(apv, av, yT, r) = (yT + av - apv / (1 + r))

function CES_aggregator(sw::SOE, cT, cN)
    ϖN, ϖT, η = (sw.pars[key] for key in (:ϖN, :ϖT, :η))

    return (ϖN * cN^-η + ϖT * cT^-η)^(-1 / η)
end    

function prod_N(sw::SOE, h)
    # Computes production of nontradables at input h

    yN = h^sw.pars[:α]
    return yN
end

function H(sw::SOE, cT, w)
    # Computes labor supply consistent with consumption of tradables + wage
    α, η, ϖN, ϖT = (sw.pars[key] for key in (:α, :η, :ϖN, :ϖT))

    return (ϖN / ϖT * α / w)^(1 / (1 + α * η)) * cT^((1 + η) / (1 + α * η))
end

function eq_h(sw::SOE, cT)
    # Computes labor supply consistent with consumption of tradables
    Ls = 1

    h = H(sw, cT, sw.pars[:wbar])
    labor = min(h, Ls)
    return labor
end

function budget_constraint_agg(apv, av, yT, r, sw::SOEpl)
    cT = budget_constraint_T(apv, av, yT, r)

    cT = max(0, cT)

	hN = eq_h(sw, cT)
	yN = prod_N(sw, hN)

	return CES_aggregator(sw, cT, yN)
end

function eval_value(apv, av, yT, pz, itp_v, sw::SOEpl)
    β, r = (sw.pars[key] for key in (:β, :r))
    
    c = budget_constraint_agg(apv, av, yT, r, sw)
    u = utility(c, sw)

    Ev = expect_v(apv, pz, itp_v, sw)

    return u + β * Ev
end

function collateral(ap, av, yT, sw::SOEpl)
	r, ϖN, ϖT, η, κ = (sw.pars[key] for key in (:r, :ϖN, :ϖT, :η, :κ))

	cT = budget_constraint_T(ap, av, yT, r)

    cT = max(0.0, cT)

	hN = eq_h(sw, cT)
	yN = prod_N(sw, hN)

	pN = ϖN / ϖT * ( cT / yN )^(1+η)

	return -κ * (yT + pN * yN)
end

function find_amin(av, yT, sw::SOEpl)

	obj_f(ap) = (collateral(ap, av, yT, sw) - ap)^2
	amin, amax = extrema(sw.agrid)

	res = Optim.optimize(obj_f, amin, amax)

	return res.minimizer
end

function optim_value(av, yT, pz, itp_v, sw::SOEpl)
    r = sw.pars[:r]

    obj_f(x) = eval_value(x, av, yT, pz, itp_v, sw)
    amin, amax = extrema(sw.agrid)

    if haskey(sw.pars, :κ) && sw.pars[:κ] > -Inf
        a_constraint = find_amin(av, yT, sw)
        amin = max(amin, a_constraint)
    end

    res = Optim.maximize(obj_f, amin, amax)

    apv = Optim.maximizer(res)
    v = Optim.maximum(res)

    c = budget_constraint_agg(apv, av, yT, r, sw)

    return v, apv, c
end

function vf_iter!(new_v, sw::SOEpl)
    itp_v = interpolate((sw.agrid, sw.zgrid), sw.v, Gridded(Linear()))

    for (ja, av) in enumerate(sw.agrid), (jz, zv) in enumerate(sw.zgrid)
		yT = zv

		pz = sw.Pz[jz, :]
		
		v, apv, c = optim_value(av, yT, pz, itp_v, sw)

		new_v[ja, jz] = v
		sw.ga[ja, jz] = apv
		sw.gc[ja, jz] = c
	end
end
