##########################################
# Housekeeping
#########################################

pwd()
cd("C:\\Users\\jclop\\Dropbox\\Maestria\\Teaching\\Open Macro")

##########################################
# Warming Up
##########################################

using Distributions, Statistics, PlotlyJS

function rep()

    N = 0   # para la cantidad de extracciones
    X = 0.0 # para X_i
    S = 0.0 # para la suma
    z = 0.0 # para X_1

    while S < 1
        N += 1      # voy contando cuántas extracciones hice
        X = rand()  # extraigo X_i
        S += X      # suma parcial hasta i
        if N == 1   # guardo el primer elemento
            z += X
        end
    end             # En este punto el último X sigue en la memoria

    return N, X, S, z  # devuelvo la cantidad de extracciones, el último X, la suma total, el primer X
end

function dist_rep(T = 1000)
    
    Nvec = Vector{Int64}(undef, T)
    Xvec = Vector{Float64}(undef, T)
    Svec = Vector{Float64}(undef, T)
    zvec = Vector{Float64}(undef, T)

    for jt in 1:T
        N, X, S, z = rep()
        Nvec[jt], Xvec[jt], Svec[jt], zvec[jt],  = N, X, S, z
    end
    EN = mean(Nvec)
    ExN = mean(Xvec)
    Ex1 = mean(zvec)
    print("E[N] = $(EN)\n")
    print("E[Xₙ] = $(round(ExN, digits=4))\n")
    print("E[X₁] = $(round(Ex1, digits=4))\n")
    return Nvec, Xvec, Svec, zvec # Lo devuelvo para tomarlo la funcion siguiente
end

function makeplots(;T = 1000)
    Nvec, Xvec, Svec, zvec = dist_rep(T)
    T = length(Nvec)

    hN = histogram(x = Nvec, name="Repeticiones", histnorm="probability density")
    hX = histogram(x = Xvec, opacity = 0.75, name="X<sub>N</sub></i>", histnorm="probability density")
    hS = histogram(x = Svec, name="Suma", histnorm = "probability density")
    hz = histogram(x = zvec, opacity = 0.75, name="X<sub>1</sub></i>", histnorm="probability density")

    pN = plot(hN, Layout(title="Distribución de <i>N"))
    pS = plot(hS, Layout(title="Distribución de <i>Σᵢ Xᵢ"))
    pXz = plot([hX, hz], Layout(title="Distribución empírica de Xᵢ", barmode="overlay"))

    return pN, pS, pXz
end

pN, pS, pXz = makeplots();

pN
pS
pXz

##########################################
# An Optimization Problem About Nothing
##########################################

using LinearAlgebra, Expectations, NLsolve, Roots, Random, Parameters

# Constant objects

N = 6
Dist = Uniform()
E = expectation(Dist; n=N)
Q = range(0, 1, length=N)

δ = 0.8
NumPlots = 6

############## By Iteration ##############

# Define operator
T(V) = max.(Q, δ*E*V)

VS = rand(Uniform(), N, NumPlots) # Random data
VS[:, 1] .= Q # Initial guess of "Accept Everyone"

for Col in 2:NumPlots
    VLast = VS[:, Col - 1]
    VS[:, Col] .= T(VLast) # Manually applying operator
end

plot(Q, VS)

############## With a Function ##############

function ComputeQ(Params; IVQ = collect(Q), MaxIter = 500, Tol = 1e-6)
        
    @unpack δ, Q = Params
    T(V) = max.(Q, δ*E*V)

    V = copy(IVQ)
    VNext = similar(V)
    i = 0
    Error = Inf
    while i < MaxIter && Error > Tol
        VNext .= T(V)
        Error = norm(VNext - V)
        i += 1
        V .= VNext  
    end
    return δ*E*V

end

Paramet = @with_kw (δ=0.8, Q=Q)
ComputeQ(Paramet())

############## With a Package ##############

function ComputeQ(Params; IVQ = collect(Q), MaxIter = 500, Tol = 1e-6, m = 6)

    @unpack δ, Q = Params
    T(V) = max.(Q, δ*E*V)

    VStar = fixedpoint(T, IVQ, iterations = MaxIter, ftol = Tol, m = 0).zero
    return (δ*E*VStar)

end

Paramet = @with_kw (δ=0.8, Q=Q)
ComputeQ(Paramet(δ=0.8, Q=Q))

############## Shock Patience ##############

Qs = Vector{Float64}(undef, 11)
δVals = range(0.0, 1, length = 11)

for (s, j) in enumerate(δVals)

    Qs[s] = ComputeQ(Paramet(δ=j, Q=Q))

end

plot(δVals, Qs)