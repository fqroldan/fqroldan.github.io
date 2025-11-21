using Random
include("arellano.jl")

struct SimulPath
    names::Dict{Symbol,Int64}
    data::Matrix{Float64}
end

function SimulPath(T, nv::Vector{Symbol})
    K = length(nv)
    data = zeros(T, K)
    names = Dict(key => jk for (jk, key) in enumerate(nv))

    return SimulPath(names, data)
end

horizon(pp::SimulPath) = size(pp.data, 1)
Base.eachindex(pp::SimulPath) = axes(pp.data, 1)

Base.getindex(pp::SimulPath, s::Symbol) = pp.data[:, pp.names[s]]

Base.getindex(pp::SimulPath, j::Int64, s::Symbol) = pp.data[j, pp.names[s]]
Base.getindex(pp::SimulPath, s::Symbol, j::Int64) = pp.data[j, pp.names[s]]
Base.getindex(pp::SimulPath, ::Colon, s::Symbol) = pp.data[:, pp.names[s]]
Base.getindex(pp::SimulPath, s::Symbol, ::Colon) = pp.data[:, pp.names[s]]

Base.setindex!(pp::SimulPath, x::Real, j::Int64, s::Symbol) = (pp.data[j, pp.names[s]] = x)
Base.setindex!(pp::SimulPath, x::Real, s::Symbol, j::Int64) = (pp.data[j, pp.names[s]] = x)

Base.keys(pp::SimulPath) = keys(pp.names)

subpath(pp::SimulPath, t0, t1) = SimulPath(pp.names, pp.data[t0:t1, :])

get_spread(qt, dd::Default) = get_spread(qt, dd.pars[:κ])
get_spread(qt, κ::Number) = κ * (1/qt - 1)

function moments(pp::SimulPath)

    M = Dict{Symbol, Float64}();

    rep_indices = [t for t in eachindex(pp) if pp[:d, t] == 0]

    M[:debtGDP] = mean(pp[:by][rep_indices]) * 100
    M[:avgspr] = mean(pp[:spr][rep_indices]) * 10_000
    M[:stdspr] = std(pp[:spr][rep_indices]) * 10_000

    return M
end

function simul(dd::Default; T = 1000, b0 = 0., y0 = 1., d0 = 0)
    # d = 0 => repago, d = 1 => default

    pp = SimulPath(T, [:y, :b, :d, :q, :c, :spr, :by])

    itp_q = make_itp(dd, dd.q)
    itp_gb = make_itp(dd, dd.gb)
    itp_def = make_itp(dd, dd.prob)

    for t in 1:T

        pp[:b, t] = b0
        pp[:y, t] = y0
        pp[:by,t] = b0 / (4*y0)

        dt, bp, ct, qt = acciones_t(itp_def, itp_gb, itp_q, d0, b0, y0, dd)

        pp[:d, t] = dt
        pp[:c, t] = ct
        pp[:q, t] = qt


        spr = (1+get_spread(qt, dd))^4 - 1
        pp[:spr, t] = spr

        yp = transicion_t(y0, dd)

        b0, y0, d0 = bp, yp, dt
    end

    return pp
end

function transicion_t(y0, dd)
    ρ, σ = (dd.pars[k] for k in (:ρy, :σy))

    # z = log(y)
    # z' = ρz + σϵ, ϵ ~ Normal(0,1)

    zp = ρ * log(y0) + σ * rand(Normal(0,1))
    yp = exp(zp)

    yp = max(min(yp, maximum(dd.ygrid)), minimum(dd.ygrid))
    return yp
end

function acciones_t(itp_def, itp_gb, itp_q, d0, bt, yt, dd)
    ψ = dd.pars[:ψ]
    ℏ = ifelse(haskey(dd.pars, :ℏ), dd.pars[:ℏ], 1)

    bp = bt

    sigo = 0
    if d0 == 1
        ϵ = rand()
        if ϵ < 1-ψ
            sigo = 1
        else
            sigo = 0
        end
    end

    if sigo == 1
        dt = 1
    else
        prob = itp_def(bt, yt)
        ϵ = rand()
        if ϵ < prob
            dt = 1
            bp = (1-ℏ) * bt
        else
            dt = 0
        end
    end

    if dt == 1
        ct = h(yt, dd)
        qt = NaN
    else
        bp = itp_gb(bt, yt)
        qt = itp_q(bp, yt)
        ct = budget_constraint(bp, bt, yt, qt, dd)
    end

    return dt, bp, ct, qt
end
