include("arellano.jl")

function simul(dd::Arellano; T=100, b0=dd.bgrid[1], y0=mean(dd.ygrid), d0=1)
    ρy, σy, ψ = (dd.pars[key] for key in (:ρy, :σy, :ψ))
    ymin, ymax = extrema(dd.ygrid)

    bvec = zeros(T)
    cvec = zeros(T)
    yvec = zeros(T)
    dvec = zeros(T)
    qvec = zeros(T)
    pvec = zeros(T)

    knts = (dd.bgrid, dd.ygrid)
    itp_gb = interpolate(knts, dd.gb, Gridded(Linear()))
    itp_q = interpolate(knts, dd.q, Gridded(Linear()))
    itp_def = interpolate(knts, dd.prob, Gridded(Linear()))

    itp_gc = interpolate((dd.bgrid, dd.ygrid, 1:2), dd.gc, Gridded(Linear()))

    for jt in 1:T

        bvec[jt] = b0
        yvec[jt] = y0
        dvec[jt] = d0

        # un montón de cuentas en el momento jt

        emision, ct, qt = simul_t(b0, y0, d0, itp_gb, itp_gc, itp_q)
        cvec[jt] = ct
        qvec[jt] = qt

        b0, y0, d0, prob_def = transicion_estados(emision, y0, d0, ρy, σy, ψ, ymin, ymax, itp_def)
        
        pvec[jt] = prob_def
    end

    return bvec, cvec, yvec, dvec, qvec, pvec
end

function simul_t(b, y, d, itp_gb, itp_gc, itp_q)
    # d=1 es repago, d=2 es default

    if d == 1 # Repago
        emision = itp_gb(b,y)
        q = itp_q(emision,y)
    elseif d == 2 # Default
        emision = b
        q = 0
    else
        throw(error("Te equivocaste en el d"))
    end

    consumo = itp_gc(b,y,d)

    return emision, consumo, q
end

function transicion_estados(bp, y, d, ρy, σy, ψ, ymin, ymax, itp_def)

    ϵ = rand(Normal(0,1))
    
    yt1 = exp( ρy * log(y) + σy * ϵ )
    
    yt1 = min(ymax, max(ymin, yt1))
    
    if d == 1 # Repago
        prob_def = itp_def(bp, yt1)
    elseif d == 2 # Default
        prob_def = 1-ψ + ψ * itp_def(0,yt1)
    else
        throw(error("Te equivocaste en el d"))
    end
    
    ξ = rand()
    default = ifelse(ξ < prob_def, 2, 1) # con probabilidad prob_def, defaulteo

    bt1 = bp
    if d == 1 && default == 2
        bt1 = 0.
    end

    return bt1, yt1, default, prob_def
end


