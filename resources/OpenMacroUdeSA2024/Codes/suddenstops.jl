include("SGU.jl")

struct SOEbr <: SOE
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

function SOEbr(; β = 0.97, γ = 2, r = 0.02, ϖN = 0.55, η = 1/0.83-1, κ = 0.35, α = 0.67, wbar = 0.8, ρz = 0.945, σz = 0.02, Na = 40, Nz = 21, amin = -0.5, amax = 10)

	ϖT = 1 - ϖN

	pars = Dict(:β => β, :γ => γ, :r => r, :ϖN => ϖN, :ϖT => ϖT, :η => η, :κ => κ, :α => α, :wbar => wbar)

	agrid = cdf.(Beta(2,1), range(0,1, length=Na))
	agrid = amin .+ (amax-amin)*agrid

	zchain = tauchen(Nz, ρz, σz, 0, 3)
	zgrid = exp.(zchain.state_values)
	Pz = zchain.p

	v = ones(Na, Na, Nz)
	gc = ones(Na, Na, Nz)
	ga = ones(Na, Na, Nz)

	pN = ones(Na, Nz)
	w = ones(Na, Nz)
	Ap = [av for av in agrid, zv in zgrid]
	Y  = [exp(zv) for av in agrid, zv in zgrid]

	return SOEbr(pars, agrid, zgrid, Pz, v, gc, ga, pN, w, Ap, Y)
end

function optim_value(av, yv, Apv, pz, pCv, itp_v, sw::SOEbr)
	r, κ = (sw.pars[sym] for sym in (:r, :κ))

	obj_f(x) = eval_value(x, av, yv, Apv, pz, pCv, itp_v, sw)
	amin, amax = extrema(sw.agrid)

    amin = max(amin, -κ * pCv * yv)

    budget_constraint(amin, av, yv, r, pCv) > 0 || throw(error("Feasible set empty at $av, $yv"))
    
    res = Optim.maximize(obj_f, amin, amax)
    
    apv = Optim.maximizer(res)
    v  = Optim.maximum(res)
    
    c = budget_constraint(apv, av, yv, r, pCv)

	return v, apv, c
end
