using QuantEcon, Optim, Interpolations, LinearAlgebra, PlotlyJS, Distributions

abstract type Deuda end

struct NoDefault <: Deuda
    pars::Dict{Symbol,Float64}

    bgrid::Vector{Float64}
    ygrid::Vector{Float64}
    Py::Matrix{Float64}

    v::Matrix{Float64}

    gc::Matrix{Float64}
    gb::Matrix{Float64}
end

function NoDefault(;
    β=0.96,
    γ=2,
    r=0.017,
    ρy=0.945,
    σy=0.025,
    Nb=200,
    Ny=21,
    bmax=0.9
)

    pars = Dict(:β => β, :γ => γ, :r => r, :ρy => ρy, :σy => σy, :Nb => Nb, :Ny => Ny, :bmax => bmax)

    ychain = tauchen(Ny, ρy, σy, 0, 2)

    Py = ychain.p
    ygrid = exp.(ychain.state_values)

    bgrid = range(0, bmax, length=Nb)

    v = zeros(Nb, Ny)
    gc = zeros(Nb, Ny)
    gb = zeros(Nb, Ny)

    return NoDefault(pars, bgrid, ygrid, Py, v, gc, gb)
end

u(cv, dd::Deuda) = u(cv, dd.pars[:γ])
function u(cv, γ::Real)
    cmin = 1e-3
    if cv < cmin
        # Por debajo de cmin, lineal con la derivada de u en cmin
        return u(cmin, γ) + (cv - cmin) * cmin^(-γ)
    else
        if γ == 1
            return log(cv)
        else
            return cv^(1 - γ) / (1 - γ)
        end
    end
end

# consumo es ingreso más ingresos por vender deuda nueva menos repago de deuda vieja
budget_constraint(bpv, bv, yv, q, dd::Deuda) = yv + q * bpv - bv

# LA MAGIA DEL MULTIPLE DISPATCH
debtprice(dd::NoDefault, bpv, yv, itp_q) = 1/(1+dd.pars[:r])

function eval_value(jb, jy, bpv, itp_q, itp_v, dd::Deuda)
    """ Evalúa la función de valor en (b,y) para una elección de b' """
    β = dd.pars[:β]
    bv, yv = dd.bgrid[jb], dd.ygrid[jy]

    # Interpola el precio de la deuda para el nivel elegido
    qv = debtprice(dd, bpv, yv, itp_q)

    # Deduce consumo del estado, la elección de deuda nueva y el precio de la deuda nueva
    cv = budget_constraint(bpv, bv, yv, qv, dd)

    # Evalúa la función de utilidad en c
    ut = u(cv, dd)

    # Calcula el valor esperado de la función de valor interpolando en b'
    Ev = 0.0
    for (jyp, ypv) in enumerate(dd.ygrid)
        prob = dd.Py[jy, jyp]
        Ev += prob * itp_v(bpv, ypv)
    end

    # v es el flujo de hoy más el valor de continuación esperado descontado
    v = ut + β * Ev

    return v, cv
end

function opt_value(jb, jy, itp_q, itp_v, dd::Deuda)
    """ Elige b' en (b,y) para maximizar la función de valor """

    # b' ∈ bgrid
    b_min, b_max = extrema(dd.bgrid)

    # Función objetivo en términos de b', dada vuelta 
    obj_f(bpv) = eval_value(jb, jy, bpv, itp_q, itp_v, dd)[1]

    # Resuelve el máximo
    res = Optim.maximize(obj_f, b_min, b_max, GoldenSection())

    # Extrae el argmax
    b_star = Optim.maximizer(res)

    # Extrae v y c consistentes con b'
    vp, c_star = eval_value(jb, jy, b_star, itp_q, itp_v, dd)

    return vp, c_star, b_star
end

function vfi_iter!(new_v, itp_q, dd::NoDefault)
    # Reconstruye la interpolación de la función de valor
    knts = (dd.bgrid, dd.ygrid)
    itp_v = interpolate(knts, dd.v, Gridded(Linear()))

    for jy in eachindex(dd.ygrid), jb in eachindex(dd.bgrid)

        vp, c_star, b_star = opt_value(jb, jy, itp_q, itp_v, dd)

        # Guarda los valores para repago 
        new_v[jb, jy] = vp
        dd.gb[jb, jy] = b_star
        dd.gc[jb, jy] = c_star
    end
end

# LA MAGIA DE MULTIPLE DISPATCH
make_itp(dd::NoDefault) = 1/(1+dd.pars[:r])

function vfi!(dd::Deuda; tol::Float64=1e-8, maxiter=2000, verbose=true)
    """ Itera sobre la ecuación de Bellman del país para encontrar la función de valor, probabilidad de default, consumo en repago y en default """
    new_v = similar(dd.v)

    dist = 1 + tol
    iter = 0

    # Interpolación del precio de la deuda (si hace falta)
    itp_q = make_itp(dd)

    # Loop principal sobre la Bellman del país
    while dist > tol && iter < maxiter
        iter += 1

        vfi_iter!(new_v, itp_q, dd)

        # Distancia entre la función de valor y el guess viejo 
        dist = norm(new_v - dd.v) / (1 + norm(dd.v))

        # Actualiza la función de valor 
        dd.v .= new_v
        verbose && print("Iteration $iter. Distance = $dist\n")
    end
    dist < tol && print("✓")
end