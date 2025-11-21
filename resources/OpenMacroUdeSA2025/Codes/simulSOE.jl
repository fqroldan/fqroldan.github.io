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


function iter_simul!(tt, pp, itp_ga, itp_w, itp_Y, itp_pN, At, zt, sw::SOE)

    # ϖN, ϖT, η = (sw.pars[sym] for sym in (:ϖN, :ϖT, :η))
    r, ρz, σz = (sw.pars[sym] for sym in (:r, :ρz, :σz))

    w = itp_w(At, zt)
    Y = itp_Y(At, zt)
    pN = itp_pN(At, zt)
    pC = price_index(pN, sw)

    Ap = itp_ga(At, At, zt)

    C = budget_constraint(Ap, At, Y, r, pC)

    # cT = C * ϖT * (pC)^η
    # cN = C * ϖN * (pC/pN)^η

    CA = Y - pC * C

    pp[:CA, tt] = CA
    pp[:pN, tt] = pN
    pp[:w, tt] = w
    pp[:Y, tt] = Y
    pp[:C, tt] = C
    pp[:A, tt] = At
    pp[:z, tt] = zt


    amin, amax = extrema(sw.agrid)
    Ap = max(amin, min(amax, Ap))

    ϵ_new = rand(Normal(0, 1))
    zp = exp(ρz * log(zt) + σz * ϵ_new)

    zmin, zmax = extrema(sw.zgrid)
    zp = max(zmin, min(zmax, zp))

    return Ap, zp
end

function simul(sw::SOE; T=1000)

    pp = SimulPath(T, [:w, :Y, :CA, :C, :pN, :A, :z])

    itp_ga = interpolate((sw.agrid, sw.agrid, sw.zgrid), sw.ga, Gridded(Linear()))

    itp_w = interpolate((sw.agrid, sw.zgrid), sw.w, Gridded(Linear()))
    itp_Y = interpolate((sw.agrid, sw.zgrid), sw.Y, Gridded(Linear()))
    itp_pN = interpolate((sw.agrid, sw.zgrid), sw.pN, Gridded(Linear()))

    A0 = 0.0
    z0 = 1.0
    for tt in 1:T
        A0, z0 = iter_simul!(tt, pp, itp_ga, itp_w, itp_Y, itp_pN, A0, z0, sw)
    end
    return pp
end


function iter_simul!(tt, pp, itp_ga, itp_w, itp_Y, itp_pN, At, zt, ξt, sw::SOEnews)

    # ϖN, ϖT, η = (sw.pars[sym] for sym in (:ϖN, :ϖT, :η))
    r, ρz, σz = (sw.pars[sym] for sym in (:r, :ρz, :σz))

    w = itp_w(At, zt, ξt)
    Y = itp_Y(At, zt, ξt)
    pN = itp_pN(At, zt, ξt)
    pC = price_index(pN, sw)

    Ap = itp_ga(At, At, zt, ξt)

    C = budget_constraint(Ap, At, Y, r, pC)

    # cT = C * ϖT * (pC)^η
    # cN = C * ϖN * (pC/pN)^η

    CA = Y - pC * C

    pp[:CA, tt] = CA
    pp[:pN, tt] = pN
    pp[:w, tt] = w
    pp[:Y, tt] = Y
    pp[:C, tt] = C
    pp[:A, tt] = At
    pp[:z, tt] = zt
    pp[:ξ, tt] = ξt


    amin, amax = extrema(sw.agrid)
    Ap = max(amin, min(amax, Ap))

    ϵ_new = rand(Normal(0, 1))
    ξp = exp(ρz * log(ξt) + σz * ϵ_new)
    
    ξmin, ξmax = extrema(sw.ξgrid)
    ξp = max(ξmin, min(ξmax, ξp))

    zp = ξt
    zmin, zmax = extrema(sw.zgrid)
    zp = max(zmin, min(zmax, zp))

    return Ap, zp, ξp
end

function simul(sw::SOEnews; T = 1000)

    itp_ga = interpolate((sw.agrid, sw.agrid, sw.sw.zgrid, sw.ξgrid), sw.ga, Gridded(Linear()))

    itp_w = interpolate((sw.agrid, sw.zgrid, sw.ξgrid), sw.w, Gridded(Linear()))
    itp_Y = interpolate((sw.agrid, sw.zgrid, sw.ξgrid), sw.Y, Gridded(Linear()))
    itp_pN = interpolate((sw.agrid, sw.zgrid, sw.ξgrid), sw.pN, Gridded(Linear()))

    A0 = 0.0
    z0 = 1.0
    ξ0 = 1.0
    for tt in 1:T
        A0, z0, ξ0 = iter_simul!(tt, pp, itp_ga, itp_w, itp_Y, itp_pN, A0, z0, ξ0, sw)
    end
    return pp
end



