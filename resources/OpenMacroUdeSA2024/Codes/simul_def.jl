include("arellano.jl")

function simul(dd::Arellano; T = 250, b0 = 0., y0 = 1., d0 = false)

    bvec = zeros(T)
    yvec = zeros(T)
    cvec = zeros(T)
    dvec = Vector{Bool}(undef, T)

    itp_gb = make_itp(dd, dd.gb)
    itp_prob = make_itp(dd, dd.prob)
    itp_gc = make_itp(dd, dd.gc)

    for jt in 1:T

        # Guardo el estado
        bvec[jt] = b0
        yvec[jt] = y0
        dvec[jt] = d0


        # Me fijo cómo actúo en t
        bp, c = action_t(b0, y0, d0, itp_gb, itp_gc)

        cvec[jt] = c

        # Realizo los shocks para ir a t+1
        yp, dp = transition(bp, y0, d0, itp_prob, dd)

        # Si defaulteo, vamos a 0 deuda
        if d0 == false && dp == true
            bp = 0.
        end

        # Lo que en t es mañana, en t+1 es hoy
        b0 = bp
        y0 = yp
        d0 = dp
    end

    return bvec, yvec, dvec, cvec
end

function action_t(b, y, d, itp_gb, itp_gc)

    if d == true # En Default
        c = itp_gc(b, y, 2)
        bp = b
    else # En repago
        c = itp_gc(b,y,1)
        bp = itp_gb(b,y)
    end

    return bp, c
end

function transition(bp, y, d, itp_prob, dd)
    ymin, ymax = extrema(dd.ygrid)
    ρ, σ, ψ = dd.pars[:ρy], dd.pars[:σy], dd.pars[:ψ]

    ly = log(y)
    ϵ = rand(Normal(0,1))
    lyp = ρ * ly + σ * ϵ
    yp = exp(lyp)

    yp = max(ymin, min(ymax, yp))

    if d == true # en Default
        prob_def = 1-ψ
    else # en repago
        prob_def = itp_prob(bp, yp)
    end

    ξ = rand()
    dp = (ξ < prob_def)

    return yp, dp
end