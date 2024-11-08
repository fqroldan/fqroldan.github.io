include("arellano.jl")

struct DeudaLarga{T<:Costo} <: Default
    pars::Dict{Symbol,Float64}

    bgrid::Vector{Float64}
    ygrid::Vector{Float64}
    Py::Matrix{Float64}

    v::Matrix{Float64}
    vR::Matrix{Float64}
    vD::Matrix{Float64}
    prob::Matrix{Float64}

    gc::Array{Float64,3}
    gb::Array{Float64,2}

    q::Array{Float64, 3}
end

function switch_ρ!(dd::DeudaLarga, ρ)
    dd.pars[:κ] = dd.pars[:r]+ρ
    dd.pars[:ρ] = ρ
    nothing
end

function DeudaLarga(; T = OG,
    β=0.953,
    γ=2,
    r=0.017,
    ψ=0.282,
    χ=0.01,
    Δ=0.1,
    d0=-0.18819,
    d1=0.24558,
    ℏ=0.4,
    ρy=0.945,
    σy=0.025,
    Nb=200,
    Ny=21,
    ρ = 0.05,
    bmax=1.5,
)
    κ = r+ρ

    pars = Dict(:β => β, :γ => γ, :r => r, :ψ => ψ, :χ => χ, :ρy => ρy, :σy => σy, :κ => κ, :ρ => ρ, :ℏ => ℏ)

    if T == Lin
        pars[:Δ] = Δ
    elseif T == Quad
        pars[:d0] = d0
        pars[:d1] = d1
    end

    ychain = tauchen(Ny, ρy, σy, 0, 2)

    Py = ychain.p
    ygrid = exp.(ychain.state_values)

    bgrid = range(0, bmax, length=Nb)

    v = zeros(Nb, Ny)
    vR = zeros(Nb, Ny)
    vD = zeros(Nb, Ny)
    prob = zeros(Nb, Ny)

    gc = zeros(Nb, Ny, 2)
    gb = zeros(Nb, Ny)

    q  = ones(Nb, Ny, 2)

    return DeudaLarga{T}(pars, bgrid, ygrid, Py, v, vR, vD, prob, gc, gb, q)
end

function cambiar_costo(dd::DeudaLarga, T; Δ=0.1, d0=-0.18819, d1=0.24558)

    d2 = DeudaLarga{T}(copy(dd.pars), copy(dd.bgrid), copy(dd.ygrid), copy(dd.Py), copy(dd.v), copy(dd.vR), copy(dd.vD), copy(dd.prob), copy(dd.gc), copy(dd.gb), copy(dd.q))

    if T == Lin
        d2.pars[:Δ] = Δ
    elseif T == Quad
        d2.pars[:d0] = d0
        d2.pars[:d1] = d1
    end

	return d2
end

h(yv, ::DeudaLarga{OG}) = defcost_OG(yv)
h(yv, dd::DeudaLarga{Lin}) = defcost_lineal(yv, dd)
h(yv, dd::DeudaLarga{Quad}) = defcost_quad(yv, dd)


function budget_constraint(bpv, bv, yv, q, dd::DeudaLarga)
    κ, ρ = dd.pars[:κ], dd.pars[:ρ]
    # consumo es ingreso más ingresos por vender deuda nueva menos repago de deuda vieja
    cv = yv + q * (bpv - (1-ρ) * bv) - κ * bv
    return cv
end

function value_default(jb, jy, dd::DeudaLarga)
    """ Calcula el valor de estar en default en el estado (b,y) """
    β, ψ = (dd.pars[sym] for sym in (:β, :ψ))
    yv = dd.ygrid[jy]

    # Consumo en default es el ingreso menos los costos de default
    c = h(yv, dd)

    # Valor de continuación tiene en cuenta la probabilidad ψ de reacceder a mercados
    Ev = 0.0
    for jyp in eachindex(dd.ygrid)
        prob = dd.Py[jy, jyp]
        Ev += prob * (ψ * dd.v[jb, jyp] + (1 - ψ) * dd.vD[jb, jyp])
    end

    v = u(c, dd) + β * Ev

    return c, v
end

function vfi_iter!(new_v, itp_q, dd::DeudaLarga)
    # Reconstruye la interpolación de la función de valor
    itp_v = make_itp(dd, dd.v)

    for jy in eachindex(dd.ygrid)
        for jb in eachindex(dd.bgrid)

            # En repago
            vp, c_star, b_star = opt_value(jb, jy, itp_q, itp_v, dd)

            # Guarda los valores para repago 
            dd.vR[jb, jy] = vp
            dd.gb[jb, jy] = b_star
            dd.gc[jb, jy, 1] = c_star

            # En default
            cD, vD = value_default(jb, jy, dd)
            dd.vD[jb, jy] = vD
            dd.gc[jb, jy, 2] = cD
        end
    end

    χ, ℏ = (dd.pars[key] for key in (:χ, :ℏ))
    itp_vD = make_itp(dd, dd.vD)
    for (jb,bv) in enumerate(dd.bgrid), (jy,yv) in enumerate(dd.ygrid)
        # Valor de repagar y defaultear llegando a (b,y)
        vr = dd.vR[jb, jy]
        vd = itp_vD(bv*(1-ℏ), yv)

        # Probabilidad de default
        ## Modo 2: valor extremo tipo X evitando comparar exponenciales de cosas grandes
        lse = logsumexp([vd / χ, vr / χ])
        lpr = vd / χ - lse
        pr = exp(lpr)
        V = χ * lse

        # Guarda el valor y la probabilidad de default al llegar a (b,y)
        new_v[jb, jy] = V
        dd.prob[jb, jy] = pr
    end
end

make_itp(dd::DeudaLarga, y::Array{Float64,3}, jdef = 1) = make_itp(dd, y[:,:,jdef])

function q_iter!(new_q, dd::DeudaLarga)
    """ Ecuación de Euler de los acreedores determinan el precio de la deuda dada la deuda, el ingreso, y el precio esperado de la deuda """
    r, κ, ρ, ℏ, ψ = (dd.pars[key] for key in (:r, :κ, :ρ, :ℏ, :ψ))

    # 1 es repago, 2 es default
    itp_q = make_itp(dd, dd.q)

    for (jbp, bpv) in enumerate(dd.bgrid), jy in eachindex(dd.ygrid)
        Eq = 0.0
        EqD = 0.0
        for (jyp, ypv) in enumerate(dd.ygrid)
            prob = dd.Py[jy, jyp]
            prob_def = dd.prob[jbp, jyp]

            bpp = dd.gb[jbp, jyp]

            qp = itp_q(bpp, ypv, 1)

            R = κ + (1-ρ) * qp

            # Si el país tiene acceso a mercados, emite y puede hacer default mañana
            rep_R = (1 - prob_def) * R + prob_def * (1 - ℏ) * itp_q((1-ℏ)*bpv, ypv, 2)
            
            Eq += prob * rep_R
            EqD += prob * (ψ * rep_R + (1-ψ) * dd.q[jbp, jyp, 2])
        end
        new_q[jbp, jy, 1] = Eq  / (1+r)
        new_q[jbp, jy, 2] = EqD / (1+r)
    end
end




lista = [
    "Franco Vazquez",
    "Facundo",
    "Luca Asteggiano Saul",
    "Gastón Marinelli",
    "Manuel Diaz de la Fuente",
    "Juan Felipe Bulacio",
    "Agustín Isern",
    "Gabriel Pessi",
    "Cesar Ciappa",
    "Raúl Sosa",
    "Jeremías Angel Manzano Quiroga",
    "Tomas Folia"
]