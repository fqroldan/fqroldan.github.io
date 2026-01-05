using Interpolations, Optim, LinearAlgebra

struct Recursivo
    pars::Dict{Symbol, Float64}

    θgrid::Vector{Float64}
    gθ::Vector{Float64}
    gy::Vector{Float64}
    gπ::Vector{Float64}

    v::Vector{Float64}
end

function Recursivo(;
    β = 1.02^(-0.25),
    γ = 60.0,
    κ = 0.17,
    ystar = 0.05,
    Nθ = 501,
    θmax = 1
    )

    pars = Dict(:β => β, :γ => γ, :κ => κ, :ystar => ystar)

    θgrid = range(0, θmax, length=Nθ)

    gθ = zeros(Nθ)
    gy = zeros(Nθ)
    gπ = zeros(Nθ)
    v = ones(Nθ)

    return Recursivo(pars, θgrid, gθ, gy, gπ, v)
end

function get_others(θv, θp, pp::Recursivo)
    γ, κ, ystar = (pp.pars[k] for k in (:γ, :κ, :ystar))

    # CPO del producto
    yv = ystar - θp * κ
    # CPO de la inflación
    πv = (θp - θv) / γ

    return yv, πv
end

function eval_value(θv, θp, itp_v, pp::Recursivo)
    γ, κ, ystar, β = (pp.pars[k] for k in (:γ, :κ, :ystar, :β))

    # Dado θ', valores consistentes de inflación y producto
    yv, πv = get_others(θv, θp, pp)

    # evaluar la función de valor cuando elegí θ', y, π, cuando el estado es θ
    v = (yv-ystar)^2 / 2 + γ * πv^2 / 2 - θp * (πv - κ*yv) + θv * πv + β * itp_v(θp)
    return v
end


function opt_value(θv, itp_v, pp::Recursivo)
    θmin, θmax = extrema(pp.θgrid)

    # Elegir θ' para maximizar la función de valor
    obj_f(θp) = -eval_value(θv, θp, itp_v, pp)
    res = Optim.optimize(obj_f, θmin, θmax, GoldenSection())

    θp = res.minimizer

    # Elecciones de inflación y producto consistentes con θp
    yv, πv = get_others(θv, θp, pp)

    # Función de valor en el máximo
    v = -res.minimum

    return v, θp, yv, πv
end

function vfi_iter!(new_v, itp_v::AbstractInterpolation, pp::Recursivo)

    for (jθ, θv) in enumerate(pp.θgrid)

        # Nuevos guesses para las funciones de valor y las variables de control
        v, θp, yv, πv = opt_value(θv, itp_v, pp)

        # Guardar
        new_v[jθ] = v
        pp.gθ[jθ] = θp
        pp.gy[jθ] = yv
        pp.gπ[jθ] = πv
    end
end

function vfi!(pp::Recursivo; tol = 1e-8, maxiter = 5000)
    dist = 1+tol
    iter = 0

    knots = (pp.θgrid,)
    new_v = similar(pp.v)
    while dist > tol && iter < maxiter
        iter += 1
        
        # Interpolar el guess más actualizado
        itp_v = interpolate(knots, pp.v, Gridded(Linear()))
        # Actualizar new_v con un guess nuevo
        vfi_iter!(new_v, itp_v, pp)

        # Distancia relativa entre iteraciones de la función de valor
        dist = norm(new_v - pp.v) / (1+norm(pp.v))

        # Mostrar cómo viene, cada 100 iteraciones
        (iter % 100 == 0) && println("Iteration $iter: dist = $dist")

        # Guardar los elementos de new_v en pp.v para continuar el algoritmo
        pp.v[:] = new_v[:]
    end
end

function simul(pp::Recursivo, T = 25)
    knots = (pp.θgrid,)
    itp_gπ = interpolate(knots, pp.gπ, Gridded(Linear()))
    itp_gy = interpolate(knots, pp.gy, Gridded(Linear()))
    itp_gθ = interpolate(knots, pp.gθ, Gridded(Linear()))

    path = Dict(k => zeros(T) for k in (:y, :π, :θ))

    θt = 0.0
    for tt in 1:T

        # Elecciones de inflación y control en el estado θt
        yt = itp_gy(θt)
        πt = itp_gπ(θt)

        path[:y][tt] = yt
        path[:π][tt] = πt
        path[:θ][tt] = θt

        # Elección del estado de mañana θ'
        θt = itp_gθ(θt)
    end

    return path
end