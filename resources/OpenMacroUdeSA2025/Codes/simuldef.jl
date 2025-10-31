include("arellano.jl")

get_spread(qt, dd::Default) = get_spread(qt, dd.pars[:κ])
get_spread(qt, κ::Number) = (κ/qt - 1) * 10000

function simul(dd::Default; T = 1000, b0 = 0., y0 = 1., d0 = 0)
    # d = 0 => repago, d = 1 => default

    yvec, bvec, dvec, qvec, cvec, svec = zeros(T), zeros(T), zeros(T), zeros(T), zeros(T), zeros(T)

    itp_q = make_itp(dd, dd.q)
    itp_gb = make_itp(dd, dd.gb)
    itp_def = make_itp(dd, dd.prob)

    for t in 1:T

        bvec[t] = b0
        yvec[t] = y0

        dt, bp, ct, qt = acciones_t(itp_def, itp_gb, itp_q, d0, b0, y0, dd)

        dvec[t] = dt
        cvec[t] = ct
        qvec[t] = qt
        svec[t] = get_spread(qt, dd)

        yp = transicion_t(y0, dd)

        b0, y0, d0 = bp, yp, dt
    end

    return yvec, bvec, dvec, qvec, cvec
end

function transicion_t(y0, dd)
    ρ, σ = (dd.pars[k] for k in (:ρy, :σy))

    # z = log(y)
    # z' = ρ z + σϵ, ϵ Normal (0,1)

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