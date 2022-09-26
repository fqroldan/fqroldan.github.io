####### Code Camp N°1 ########
####### Universidad de Sán Andrés #########
####### Maestría en Economía      #########
####### Economía Internacional    #########
####### T.A Francisco Guerrero    #########
####### 05/09/2022                #########


##### Comandos básicos  de Julia###############

## Declaración de variables 


### A continuación se listan una serie de códigos que determinan si 
### los datos de la izquierda corresponden al tipo de la derecha
### si se quiere llevar a un ejemplo práctico corresponde a una operacion 
### de tipo Assert

#### Esto como base inicial sirve para asegurar que los tipos de variables sean
#### sean los adecuados para las operaciones posteriores

#### Además sirve como ejercicio para conocer como se declaran los tipos, 
#### la organizacion de tipos y subtipos4


### Tipos Concretos : En corto aquellos tipos que se refieren a organizaciones
### especificas de datos en memoria, como cadenas de bits y demás 


### Tipos Abstractos: Elementos que no estan ligados específicamente a un 
### ordenamiento específico en memoria y pueden referirse a multiples tipos de datos
### estos multiples tipos de datos pueden ordenarse como conjuntos y subcojuntos 
### de variables (Entero, Real, Fraccionario, Imaginario, Etc)


#### Declaracion de directorio, función  

pwd()

#### Cambio de directorio

cd("C:\\Users\\jguer")

pwd()



(1+2)::AbstractFloat

(1+2)::Int8

(1+2)::Int16

(1+2)::Int32

(0.25)::Int16

(-5)::Int32

(-5)::Int64

(-5)::Number

(-0.2)::Number

(1/3)::Number

(1/3)::Float64

(1/3)::Signed

(1/3)::Unsigned

(1/3)::Real

(4.0)::Float16

(4.0)::Int64

(4.0)::AbstractFloat

("Pedro")::Int64

("Maria")::AbstractString

("Maria")::String

true::Number
false::Number


#### Los Booleanos   True/False corresponden al tipo abstracto Number
-

true::Float16
true::Float64

### Sin embargo no corresponde al tipo Float16
true::Real

true::Integer

true::Any

### Los booleanos corresponden al tipo abstracto Real, de manera más granular corresponde al tipo Integer,
### naturalmente todos estos booleanos corresponden al subtipo Any


### El tipo de la función se obtiene utilizando a la función typeof, a la cual se le pasa el valor a 
### evaluar de cada elemento


typeof(true)

typeof(0.5)

typeof(1)

typeof(["Pedro","Maria"])

Array{Int64, 1} == Vector{Int64}
Array{Int64, 2} == Matrix{Int64}

typeof(Array{Int64, 1})

#### Variables, Asiganicon de variables


A = 5
B = 6
C = "Pedro"
D = "Maria"

E= [1.0, 2.0] 

F = ["Gato",2.9]

G = ["Gato","Perro"]


# Strings

x = "Open_macro"
typeof(x)

x = 300
"x = $x"

"Open " * "Macro"

s = "El veloz murciélago hindú, comía felizmente una fruta en un trigal"
split(s)



##### Generación de struct


## Declaracion
struct OpenMacro
    UdeSA
    UTDT::Int
    UCEMA::String
end

#### Inicialización
omacro = OpenMacro("Code-Camp1",2,"Gato")
### Al tener cada uno los elementos correctos te genera la estructura sin error alguno

omacro2 = OpenMacro("Code-Camp1.jl","Perro",5)
### En este caso al tener elementos que no correpsonde al tipo especificado la estrucutura no corre y por ende ende te da erroreres 


#### Con esta función se hallan los nombres de los valores de la estrucutura

fieldnames(OpenMacro)

omacro.UdeSA
omacro.UTDT
omacro.UCEMA
#### Esto es el modo de como se accede a cada uno de los métodos


#### Defino una estrucuta mutable el cual permite almacenar diferentes valores
mutable struct Paises_LAT
    Norte
    Sur::AbstractFloat
end

LAT = Paises_LAT("Peru", 2.0)
LAT2 = Paises_LAT(1,2)


#### Aqui se define una estructura de tipo punto fíjese como 
#### el comando T fuerza a que los datos sean del mismo tipo
struct Point{T}
    x::T
    y::T
end

Point{Float64}

nb = Point{Float64}

nc = Point{Float16}

nb = Point{Float64}(1.0, 2.0)

nc = Point{Float16}(1.0,2000000000000000000000000000000000.00000000000000000)

Point(1.0,2.0)

struct Vector_Macro{T}
    a::T
    b::T
    c::T
end

Vector_Macro("X","aa","44")

Vector_Macro(2,2,2)
####### Asignacion de variables

A = 1.0
B = A

A = 5
B = 52


A::Int64

n_1 = Vector{Any}(undef, 20)

n_2 = Vector{Int16}(undef, 20)

n_3 = Vector{Float64}(undef,20)

n_4 = Vector{Number}(undef,20)

n_5 = Vector{String}(undef,20)


#### operaciones

### Adicion

a = 5
b = 2
c = 3
d = 4
e = 5
g =6 


a::Int64

h =0.2::Float64

a+b
a+c
a+d
a+e
g

a+h::Float64
### Sustracción


a-b
a-c
a-d
a-e
a-g




### Multiplicacion


a*b
a*c
a*d
a*e
a*f

3a - 2g

3c * 4b

@show 3a * 2;


@show 3c - 5d;
### División

a/b
a/c
a/d
a/e
a/f


#### Ejercicios


#### Suma de los primeros números enteros


n = 5
n*(n+1)/2
#### Suma de los primeros números pares

n = 3
n*(n+1)

#### Suma de los primeros números impares

n = 3
n*n


### Suma de ángulos de un polígono regular

n = 4|

(n-2)*180


#### Bascara

a = 3
b = 1
c= 4

(-b + sqrt(b^2- 4*a*c))/(2*a) 



#### Funciones aparte