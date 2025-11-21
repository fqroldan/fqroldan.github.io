# Para hacer en común en la clase

include("SGU.jl")

struct SOEnews <: SOE
    pars::Dict{Symbol,Float64}

    agrid::Vector{Float64}
    zgrid::Vector{Float64}
    ξgrid::Vector{Float64}
    Pz::Matrix{Float64}

    v::Array{Float64,4}
    gc::Array{Float64,4}
    ga::Array{Float64,4}

    pN::Array{Float64,3}
    w::Array{Float64,3}
    Ap::Array{Float64,3}
    Y::Array{Float64,3}
end

function SOEwr(; β=0.97, γ=2, r=0.02, ϖN=0.55, η=1 / 0.83 - 1, α=0.67, wbar=0.35, ρz=0.945, σz=0.025, Na=40, Nz=21, Nξ = Nz, amin=-1, amax=4)

    ϖT = 1 - ϖN

    pars = Dict(:β => β, :γ => γ, :r => r, :ϖN => ϖN, :ϖT => ϖT, :η => η, :α => α, :wbar => wbar, :ρz => ρz, :σz => σz)

    # agrid = cdf.(Beta(2,1), range(0,1, length=Na))
    # agrid = amin .+ (amax-amin)*agrid
    agrid = range(amin, amax, length=Na)

    zchain = tauchen(Nz, ρz, σz, 0, 3)
    zgrid = exp.(zchain.state_values)
    ξgrid = exp.(zchain.state_values)
    Pz = zchain.p

    v = ones(Na, Na, Nz, Nξ)
    gc = ones(Na, Na, Nz, Nξ)
    ga = ones(Na, Na, Nz, Nξ)

    pN = ones(Na, Nz, Nξ)
    w = ones(Na, Nz, Nξ)
    Ap = [Av for Av in agrid, zv in zgrid, _ in ξgrid]
    Y = [zv for av in agrid, zv in zgrid, _ in ξgrid]

    return SOEnews(pars, agrid, zgrid, ξgrid, Pz, v, gc, ga, pN, w, Ap, Y)
end


function expect_v(apv, Apv, ξv, pξ, itp_v, sw::SOEnews)
    Ev = 0.0
    for (jξp, ξpv) in enumerate(sw.zgrid)
        prob = pξ[jξp]
        Ev += prob * itp_v(apv, Apv, ξv, ξpv)
    end
    return Ev
end

function eval_value(apv, av, yv, Apv, ξv, pξ, pCv, itp_v, sw::SOEnews)
    β, r = (sw.pars[key] for key in (:β, :r))

    c = budget_constraint(apv, av, yv, r, pCv)
    u = utility(c, sw)

    Ev = expect_v(apv, Apv, ξv, pξ, itp_v, sw)

    return u + β * Ev
end

function optim_value(av, yv, Apv, ξv, pξ, pCv, itp_v, sw::SOEnews)

    obj_f(x) = eval_value(x, av, yv, Apv, ξv, pξ, pCv, itp_v, sw)
    amin, amax = extrema(sw.agrid)

    res = Optim.maximize(obj_f, amin, amax)

    apv = Optim.maximizer(res)
    v = Optim.maximum(res)

    c = budget_constraint(apv, av, yv, sw.pars[:r], pCv)

    return v, apv, c
end

function vf_iter!(new_v, sw::SOEnews)
    itp_v = interpolate((sw.agrid, sw.agrid, sw.zgrid), sw.v, Gridded(Linear()))

    for jA in eachindex(sw.agrid), jz in eachindex(sw.zgrid), jξ in eachindex(sw.ξgrid)
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


function iter_LoM!(sw::SOEnews; upd_η=1)
    for jA in eachindex(sw.agrid), jz in eachindex(sw.zgrid), jξ in eachindex(sw.ξgrid)
        sw.Ap[jA, jz, jξ] = (1 - upd_η) * sw.Ap[jA, jz, jξ] + upd_η * sw.ga[jA, jA, jz, jξ]
    end
end

function iter_pN!(new_p, sw::SOEnews; upd_η=1)
    minp = 0.9 * minimum(sw.pN)
    maxp = 1.1 * maximum(sw.pN)
    for (jA, Av) in enumerate(sw.agrid), (jz, zv) in enumerate(sw.zgrid), jξ in enumerate(sw.ξgrid)
        C = sw.gc[jA, jA, jz, jξ]

        yT = zv
        obj_f(x) = diff_pN(x, C, yT, sw)[1]

        res = Optim.optimize(obj_f, minp, maxp)

        p = sw.pN[jA, jz, jξ] * (1 - upd_η) + res.minimizer * upd_η
        new_p[jA, jz, jξ] = p

        _, y, w = diff_pN(p, C, yT, sw)
        sw.Y[jA, jz, jξ] = y
        sw.w[jA, jz, jξ] = w
    end
end
