##########################################
# Housekeeping
##########################################

pwd()
cd("C:\\Users\\jclop\\Dropbox\\Maestria\\Teaching\\Open Macro")

using Distributions, Statistics, PlotlyJS, LinearAlgebra

##########################################
# Basics
##########################################

# Boolean values

x = true
typeof(x)
?typeof
y = 1 > 2

# Floats and Integers

typeof(1) # S EEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE
typeof(1.0) # S EEEEEEEEEE FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF

1 == 1.0

@time randn(100);
@time rand(1:100, 100);

# Strings

x = "Julia"
typeof(x)

x = 10
"x = $x"

"Ju" * "lia"

s = "Julia doesn't work"
split(s)

# Algebra

x = 2
y = 1.0

x * y
2x - 3y

@show x * y;
@show 2x - 3y;

##########################################
# No me la Containers
##########################################

################# Arrays #################

a = [10, 20, 30]
a = [1.0, 2.0, 3.0]
ndims(a)
size(a)

b = [1.0 2.0 3.0]
ndims(b)
size(b)

Array{Int64, 1} == Vector{Int64}
Array{Int64, 2} == Matrix{Int64}

[1 2 3, 4 5 6, 7 8 9] 

z0=[0.0, 0.0, 0.0]
z1=zeros(3)
z0==z1
z0 = [0 0; 0 0]
z1 = zeros(2, 2)
z0==z1
z2 = fill(0.0, 2, 2)
z2 == z0 == z1

zeros(2,2,2)

x = Array{Float64}(undef, 2, 2)
x = Array{Int64}(undef, 2, 2)

#

x = [1, 2, 3]
y = x # This binds
y[1] = 2
x

x = [1, 2, 3]
y = copy(x) # This copies
y[1] = 2
x

# Indexing

a = [10 20 30 40]
a[end-1]
a[1:3]
a = randn(2, 2)
a[1, 2]
a[1, :] # Toda la fila 1
a[:, 1] # Toda la columna 1

a = randn(2, 2)
b = [true false; false true]
a[b] # Valua a en b 
b = [true true; false true]
a[b] # Valua a en b 
a

a = zeros(4)
a[2:end] .= 42 # Broadcasting
a

# Operations ("Linear Algebra")

a = [-1, 0, 1]

length(a)
sum(a)
mean(a)
std(a)
var(a)
maximum(a)
minimum(a)
extrema(a)

a = ones(1, 2)
b = ones(2, 2)
a * b
b * a'

A = [1 2; 2 3]
B = ones(2, 2)
A \ B # To solve the linear system AX = B
inv(A) * B

ones(2, 2) * ones(2, 2)
ones(2, 2) .* ones(2, 2)

A = -ones(2, 2)
A.^2
ones(2, 2) + ones(2, 2) == ones(2, 2) .+ ones(2, 2)
A = ones(2, 2)
2 * A  == 2 .* A

a = [10, 20, 30]
b = [-100, 0, 100]
b .> a
a .== b
b .> 1
a = randn(4)
a .< 0
a[a .< 0]

A = [1 2; 3 4]
det(A)
tr(A)
eigvals(A)
rank(A)

log(1.0)
log.(1:4)
[ log(x) for x in 1:4 ]

################# Tuples #################

x0 =["Ju", "lia"]
y0 =["Ju", 2]
x1 = ("Ju", "lia")
y1 = ("Ju", 2)
typeof(x0), typeof(y0), typeof(x1), typeof(y1)

t = (1.0, "test")
t[1]
a, b = t
a
b
t[1] = 3.0  # Tuples are inmutable

t = (val1 = 1.0, val2 = "test") # "Named" tuple
typeof(t)
t.val1 
a, b = t  
a
b
t[1] = 3.0

t2 = (val3 = 4, val4 = "test!!") # While immutable, it is possible to manipulate tuples and generate new ones
t3 = merge(t, t2)  # New tuple

# Named tuples are useful to manage and unpack sets of parameters

function f(parameters)
    α, β = parameters.α, parameters.β  # Poor style
    return α + β
end

parameter = (α = 0.1, β = 0.2)
f(parameter)

using Parameters

function f(parameters)
    @unpack α, β = parameters  # Good style
    return α + β
end

parameters = (α = 0.1, β = 0.2)
f(parameters)

##########################################
# Loops and Functions
#########################################

n = 100 # Parameter

ϵ = randn(n)

ϵ = zeros(n)
for i in 1:n
    ϵ[i] = randn()
end

ϵ = zeros(n)
for i in eachindex(ϵ)
    ϵ[i] = randn()
end

ϵ_sum = 0.0 # Careful to use 0.0 here, instead of 0
m = 5
for ϵ_val in ϵ[1:m] # You can loop over a value too
    ϵ_sum = ϵ_sum + ϵ_val
end

ϵ_mean = ϵ_sum / m
ϵ_mean ≈ mean(ϵ[1:m])
ϵ_mean ≈ sum(ϵ[1:m]) / m

function generatedata(n)
    ϵ = zeros(n)
    for i in eachindex(ϵ)
        ϵ[i] = (randn())^2
    end
    return ϵ
end
data = generatedata(10)

function generatedata(n)
    ϵ = randn(n) 
    for i in eachindex(ϵ)
        ϵ[i] = ϵ[i]^2
    end
    return ϵ
end
data = generatedata(10)

function generatedata(n)
    ϵ = randn(n)
    return ϵ.^2
 end
data = generatedata(10)

generatedata(n) = randn(n).^2
data = generatedata(10)

##########################################
# Outputs
#########################################

p1 = Plot([scatter(;x=1:4, y=randn(4), fill="tozeroy", name="Series 1"),
                  scatter(;x=1:10, y=[3, 5, 1, 7], fill="tonexty", name="Series 2")])
savefig(p1, "Output/MyFirstPlot.jpeg")

using Pkg
#Pkg.add("CSV")
#Pkg.add("DataFrames")
using CSV, DataFrames
 
numbers = rand(5, 5)
CSV.write("Output/MyFirstTable.csv", DataFrame(numbers, :auto), header = false)
