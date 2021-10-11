using Distributions
include("arellano.jl")

get_spr(q,κ) = 10000 * ( κ * (1/q - 1) )

function iter_simul(bt, yt, dt, itp_gc, itp_gb, itp_qR, itp_qD, itp_prob, θ, ρ, σ, κ, ℏ, ymin, ymax)
    ct = itp_gc(bt, yt, dt)

    if dt == 1 # Estoy en repago
        bp = itp_gb(bt, yt, dt)
        prob_def = itp_prob(bp, yt)
        qt = itp_qR(bp, yt)
    else
        bp = bt
        prob_def = 1-θ
        qt = itp_qD(bp, yt)
    end

    spread = get_spr(qt, κ)

    def_shock = rand()

    dp = ifelse(def_shock < prob_def, 2, 1)
    if dp == 2 && dt == 1 # Pasé de repago a default
        bp = (1-ℏ) * bp
    end

    ϵt = rand(Normal(0,1))
	yp = exp(ρ * log(yt) + σ * ϵt)

    yp = max(min(ymax, yp), ymin)

    return bp, yp, dp, ct, qt, prob_def, spread
end

function simul(dd::Default; b0 = mean(dd.bgrid), y0 = mean(dd.ygrid), d0 = 1, T = 10_000)
    θ, κ, ℏ, ρ, σ = (dd.pars[sym] for sym in (:θ, :κ, :ℏ, :ρy, :σy))
    
    ymin, ymax = extrema(dd.ygrid)

    knots_c = (dd.bgrid, dd.ygrid, 1:2)

    itp_gc = interpolate(knots_c, dd.gc, Gridded(Linear()))
    
    knots = (dd.bgrid, dd.ygrid)
    
    itp_gb = interpolate(knots, dd.gb, Gridded(Linear()))
    itp_prob = interpolate(knots, dd.prob, Gridded(Linear()))
    itp_qR = interpolate(knots, dd.q, Gridded(Linear()))
    itp_qD = interpolate(knots, dd.q, Gridded(Linear()))

    sample = Dict(sym => Vector{Float64}(undef, T) for sym in (:b, :y, :d, :c, :prob, :q, :spread))

    sample[:b][1] = b0
    sample[:y][1] = y0
    sample[:d][1] = d0
    sample[:prob][1] = 0.0
    
    for jt in 1:T

        b0, y0, d0, c, q, prob_def, spread = iter_simul(b0, y0, d0, itp_gc, itp_gb, itp_qR, itp_qD, itp_prob, θ, ρ, σ, κ, ℏ, ymin, ymax)

        sample[:c][jt] = c
        sample[:q][jt] = q
        sample[:spread][jt] = spread

        if jt < T
            sample[:b][jt+1] = b0
            sample[:y][jt+1] = y0
            sample[:d][jt+1] = d0
            sample[:prob][jt+1] = prob_def
        end
    end

    return sample
end


function samples_comp()
    dd_short = Arellano_params();
    mpe!(dd_short)

    dd_long = Default();
    mpe!(dd_long)
    T = 10_000
    sample_short = simul(dd_short, T = T)
    sample_long  = simul(dd_long,  T = T)

    return sample_short, sample_long
end

function plots_comp(sample_short, sample_long)

    plot([histogram(x=sample_short[:spread][sample_short[:d].==1], name="Short-term debt"), histogram(x=sample_long[:spread][sample_long[:d].==1], name="Long-term debt")], Layout(barmode="overlay"))

   names = ["Short-term debt", "Long-term debt"]
   plot([
       [histogram(x=x[:b]./x[:y]*100, histnorm="probability density", name=names[jx], opacity=0.65) for (jx, x) in enumerate([sample_short, sample_long])]
       scatter()
       ],
       Layout(barmode="overlay", title="Distribución de deuda/PBI"))
end