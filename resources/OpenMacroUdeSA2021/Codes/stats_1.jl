using Distributions, PlotlyJS

function rep()
    S = 0.0 # para la suma
    X = 0.0 # para X_i
    z = 0.0 # para X_1
    N = 0   # para la cantidad de extracciones
    while S < 1
        N += 1      # voy contando cuántas extracciones hice
        X = rand()  # extraigo X_i
        S += X      # suma parcial hasta i
        if N == 1   # guardo el primer elemento
            z += X
        end
    end             # En este punto el último X sigue en la memoria

    return S, X, z, N # devuelvo la suma total, el último X, el primer X, la cantidad de extracciones
end

function dist_rep(T = 1000)
    Svec = Vector{Float64}(undef, T)
    Xvec = Vector{Float64}(undef, T)
    zvec = Vector{Float64}(undef, T)
    Nvec = Vector{Int64}(undef, T)

    for jt in 1:T
        S, X, z, N = rep()
        Svec[jt], Xvec[jt], zvec[jt], Nvec[jt] = S, X, z, N
    end
    EN = mean(Nvec)
    Ex1 = mean(zvec)
    ExN = mean(Xvec)
    print("E[N] = $(EN)\n")
    print("E[X₁] = $(round(Ex1, digits=4))\n")
    print("E[Xₙ] = $(round(ExN, digits=4))\n")
    return Svec, Xvec, zvec, Nvec
end

function makeplots(;T = 1000)
    Svec, Xvec, zvec, Nvec = dist_rep(T)
    T = length(Nvec)

    sc1 = histogram(x=zvec, opacity = 0.75, name="X<sub>1</sub></i>", histnorm="probability density")
    sc2 = histogram(x=Xvec, opacity = 0.75, name="X<sub>N</sub></i>", histnorm="probability density")

    sc3 = histogram(x=Nvec, name="Repeticiones", histnorm="probability density")

    sc4 = histogram(x=Svec, name="Suma", histnorm = "probability density")

    p1 = plot([sc1, sc2], Layout(title="Distribución empírica de Xᵢ", barmode="overlay"))
    p2 = plot(sc3, Layout(title="Distribución de <i>N"))
    p3 = plot(sc4, Layout(title="Distribución de <i>Σᵢ Xᵢ"))

    return p1, p2, p3
end