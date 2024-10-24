print("Loading income fluctuations problem…")

using PlotlyJS, LinearAlgebra, Interpolations, Optim, Distributions

using QuantEcon: tauchen

abstract type Preferencias end
abstract type CRRA <: Preferencias end
abstract type Quad <: Preferencias end
abstract type CARA <: Preferencias end

struct IFP{T<:Preferencias}
    pars::Dict{Symbol,Float64}

    kgrid::Vector{Float64}
    ygrid::Vector{Float64}
    Py::Matrix{Float64}

    v::Matrix{Float64}
    gc::Matrix{Float64}
    gk::Matrix{Float64}
end

function IFP(T::DataType=CRRA; β=0.96, γ=2, r=0.02, bmax=0.9, kmin=-0.5, kmax=1, Nk=200, Ny=25, μy=1, ρy=0.8, σy=0.02)
    # Límite de deuda natural
    pars = Dict(:β => β, :γ => γ, :r => r, :ρy => ρy, :σy => σy, :Nk => Nk, :Ny => Ny, :bmax => bmax, :kmax => kmax)

    kgrid = range(kmin, kmax, length=Nk)

    ychain = tauchen(Ny, ρy, σy, 0, 2)
    ygrid = exp.(ychain.state_values) * μy
    Py = ychain.p

    v = zeros(Nk, Ny)
    gc = zeros(Nk, Ny)
    gk = zeros(Nk, Ny)

    return IFP{T}(pars, kgrid, ygrid, Py, v, gc, gk)
end

prefs(::IFP{T}) where T = T

u(cv, ce::IFP{CRRA}) = CRRA(cv, ce.pars[:γ])
u(cv, ce::IFP{Quad}) = quad_u(cv, ce.pars[:γ])
u(cv, ce::IFP{CARA}) = CARA(cv, ce.pars[:γ])

CARA(cv, γ::Number) = exp(-γ * cv)

function CRRA(cv, γ; cmin = 1e-3)
    if cv < cmin
        # Por debajo de cmin, lineal con la derivada de u en cmin
        return CRRA(cmin, γ) + (cv - cmin) * cmin^(-γ)
    else
        if γ == 1
            return log(cv)
        else
            return (cv^(1 - γ) - 1) / (1 - γ)
        end
    end
end

quad_u(cv, γ) = -(cv - γ)^2
    

function budget_constraint(kpv, kv, yv, r)
    c = kv * (1 + r) - kpv + yv
    return c
end

function eval_value(kpv, kv, yv, py, itp_v::AbstractInterpolation, ce::IFP)
    β, r = ce.pars[:β], ce.pars[:r]

    cv = budget_constraint(kpv, kv, yv, r)

    ut = u(cv, ce)

    Ev = 0.0
    for (jyp, ypv) in enumerate(ce.ygrid)
        prob = py[jyp]
        Ev += prob * itp_v(kpv, ypv)
    end

    v = ut + β * Ev

    return v
end

function opt_value(jk, jy, itp_v::AbstractInterpolation, ce::IFP)
    r = ce.pars[:r]

    kv = ce.kgrid[jk]
    yv = ce.ygrid[jy]

    k_min = minimum(ce.kgrid)
    k_max = maximum(ce.kgrid)
    k_max = min(k_max, kv * (1 + r) + yv - 1e-5)

    if k_max < k_min
        return k_min, -1e+14 * (k_min - k_max), NaN
    end

    py = ce.Py[jy, :]

    obj_f(kpv) = eval_value(kpv, kv, yv, py, itp_v, ce)

    res = Optim.maximize(obj_f, k_min, k_max, GoldenSection())

    vp = Optim.maximum(res)
    k_star = Optim.maximizer(res)

    c_star = budget_constraint(k_star, kv, yv, r)

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

function vfi!(ce::IFP; tol=1e-8, maxiter=2000, verbose=true)
    new_v = similar(ce.v)
    knts = (ce.kgrid, ce.ygrid)

    dist = 1 + tol
    iter = 0

    while dist > tol && iter < maxiter
        iter += 1

        itp_v = interpolate(knts, ce.v, Gridded(Linear()))
        vfi_iter!(new_v, itp_v, ce)

        dist = norm(new_v - ce.v) / max(1, norm(ce.v))

        ce.v .= new_v
        verbose && print("Iteration $iter. Distance = $dist\n")
    end
    dist < tol || print("✓")
end

print(" ✓\nConstructor ce = IFP(;β=0.96, r=0.02, γ=2, Nk = 20, Ny = 25, μy = 1, ρy = 0.8, σy = 0.02)\n")
print("Solver vfi!(ce::IFP; tol = 1e-8, maxiter = 2000, verbose = true)\n")

