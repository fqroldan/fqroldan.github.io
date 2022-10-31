using Distributions
include("arellano.jl")

# get_spr(q,κ) = 10000 * ( κ * (1/q - 1) )

function simul(dd::Default; b0=0.0, y0=mean(dd.ygrid), d0=1, T=10_000)

    knots_c = (dd.bgrid, dd.ygrid, 1:2)

    itp_gc = interpolate(knots_c, dd.gc, Gridded(Linear()))

    knts = (dd.bgrid, dd.ygrid)

    itp_gb = interpolate(knts, dd.gb, Gridded(Linear()))
    itp_prob = interpolate(knts, dd.prob, Gridded(Linear()))
    itp_q = interpolate(knts, dd.q[:,:,1], Gridded(Linear()))
    itp_qD= interpolate(knts, dd.q[:,:,2], Gridded(Linear()))

    sample = Dict(key => Vector{Float64}(undef, T) for key in (:b, :y, :d, :c, :prob, :q))

    sample[:b][1] = b0
    sample[:y][1] = y0
    sample[:d][1] = d0
    sample[:prob][1] = 0.0

    for jt in 1:T

        b0, y0, d0, c, q, prob_def = iter_simul(b0, y0, d0, itp_gc, itp_gb, itp_q, itp_qD, itp_prob, dd)

        sample[:c][jt] = c
        sample[:q][jt] = q

        if jt < T
            sample[:b][jt+1] = b0
            sample[:y][jt+1] = y0
            sample[:d][jt+1] = d0
            sample[:prob][jt+1] = prob_def
        end
    end

    return sample
end

function iter_simul(bt, yt, dt, itp_gc, itp_gb, itp_q, itp_qD, itp_prob, dd::DeudaLarga)
    ψ, ρ, σ, ℏ = (dd.pars[key] for key in (:ψ, :ρy, :σy, :ℏ))

    ct = itp_gc(bt, yt, dt)

    if dt == 1 # Estoy en repago
        bp = itp_gb(bt, yt, dt)
        qt = itp_q(bp, yt)
    else
        bp = bt
        qt = itp_qD(bp, yt)
    end

    ϵt = rand(Normal(0,1))
    yp = exp(ρ * log(yt) + σ * ϵt)
    
    ymin, ymax = extrema(dd.ygrid)
    yp = max(min(ymax, yp), ymin)
    
    if dt == 1
        prob_def = itp_prob(bp, yt)
    else
        prob_def = 1-ψ
    end       

    def_shock = rand()

    dp = ifelse(def_shock < prob_def, 2, 1)
    if dp == 2 && dt == 1 # Pasé de repago a default
        bp = (1-ℏ) * bp
    end

    return bp, yp, dp, ct, qt, prob_def
end
