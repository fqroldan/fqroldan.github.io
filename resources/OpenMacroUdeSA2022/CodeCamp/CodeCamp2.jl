
#### Directorio

pwd()

#cd("/Users/apple/")


### Modos prácticos de crear Vectores en Julia 

### Mediante el comando zeros, este crea un vector de largo n, cuyos
### elementos son todos zeros

A = zeros(5)

### Mediante el comando rand, este crea un vector de  largo n, cuyos
### elementos son todos numeros aleatorios

A = rand(5)
#### Se crea un vector de 5 elementos

### En Julia los elementos se cuentan desde el 1

### Accediendo al primer, segundo y tercer elemento

A[1] # 0.0
A[2] # 0.0
A[3] # 0.0 

### También se puede el comando end para acceder al ultimo elemento de un vector

A[end] 

### Para acceder a una porción de los elementos se utiliza el siguiente comando
### A[i:j]
### Dónde A es el nombre de tu vector
### i, primer elemento dónde se desea hacer la cuentan
### j, Ultimo elemento de la cuenta

#### Ejemplo
##### Genero un Vector compuesto por 50 numeros aleatorios y accedo a 11 de ellos

A_50 = rand(50)

A_50[10:20]

### En julia la selección de indice considera a todos los elementos dentro de este, en este casoo
### del 10 al 20 serían 11 elementos.

#### Asi mismo esta seleccion te permite establecer cada cuantos espacios quieras que se seleccione
#### otro elemento dentro del rango (Se le suele llamar step o paso), en este caso se selecciono
#### el elemento 10, el 15, el 20, el 25 y el 30 
A_50[10:5:30]

length(A_50)

##### JuliA tambien te permite seleccionar datos del arreglo de atrás hacia adelante


A_50[30:-5:10]

A_50[10:-1:1]

A_50[10:1]
##### Para seleccionar estos datos es necesario que el step se ponga de manera explícita
#### sino la función devolvera un arreglo vació



#### Como se puede ver 

#### Esta selección también puede guardarse en otra variable, en caso se le quiera dar un posterior uso

A_S_50 = A_50[10:5:30]

#### Para imprimir elemento por elemento utilzaremos la función for
for i in A_S_50
    print(i)
end

for i in eachindex(A_S_50)
  println(A_S_50[i])
end


for i in A_S_50
    println(i)
end

#### El for es una de las estructuras algoritmicas que permite la ejecución de ciclos
#### En Julia la forma del for es la siguiente}
#### for (i) in (Iterable)
####    ### Generacion de una o más acciones
#### end 
  


#####  Operaciones de vectores

###### Una operacion de adicion en julia toma 2 numeros y se hace de la siguiente manera
num1 = 5
num2 = 6

@show num1 + num2

#### Pero que pasa si quiero sumar un número a  un Vector
B = zeros(5)
#
#num1 + B
### A diferencia de otros lenguajes de programación, esta operacion da un error,
### en caso se quiera operar con constantes en python se utiliza antes el punto 
### ".", a esto también se le conoce como BroadCasting
B = rand(3)
#### Adición
@show B.+1

#### Sustraccion
@show B.-1

#### Multiplicacion
@show B.*2

#### División
@show B./2

#### Potencia

@show B.^2


### Diferencias entre vectores y números
### Examinemos Esto
a = 5
b = a
a = 3
b


a = [1, 2, 3]
b = a
a[1] = 2
b
a = 5
b

###### Comparaciones entre vectores
C = [20, -20, 120]

D = [-40, 0, 100]

#### Comparacion de si los elementos del Vector D son mayores a los del C
D .> C
#### Comparacion de si los elementos del Vector C son iguales a los del D
C .== D

### Se puede hacer la comparacion si los elemnentos son mayores a una constante
D .< 1000

### Asimismo se puede hacer un vector de los elementos que resulten menores a cierto valor
D = randn(8)

D .< 0

D[D .< 0]

#### Funciones de vectores
#### Inicializo un vector de nùmeros enteros aleatorios de -127 a 127.
C = rand(Int8,5)


#### Para esto cargo la librería Statistics, la cual me permitira hacer operaciones de
#### como la media, la desviación estándar, la varianza, entre otros, 
using Statistics

using Pkg
Pkg.add("Statistics")


using Statistics,Pkg, PlotlyJS, StatsBase

length(C)
sum(C)
mean(C)
std(C)
var(C)
maximum(C)
minimum(C)
extrema(C) # Devuelve los valores máximos y mínimos de un Vector

##### Un hecho relevante fue la manera como se definió, el vector "C"
##### Por defecto cuando se llama a la función zeros o la función rand
##### se iniciaba un vector de tamaño n, pero cuyo tipo de dato era Float64,
##### en cmabio aqui se inicializo un vector de datos enteros.

#### Definiendo un Vector de distintos tipos (Parece que es necesario especificar un tipo concreto)

@show D = rand(Int8,10);

@show D = rand(Int16,10);

@show D = rand(Int32,10);

@show D = rand(Bool,10);

@show D = rand(Float16,10);

@show D = rand(Float32,10);

@show D = rand(Float64,10);

@show D = rand(BigFloat,10);

ndims(B)
#### ndims revela el número de dimensiones de un arreglo, en caso de un vector 
#### su dimensión es uno

##
size(B)
length(B)
#### El comando size revela el tamaño de las dimensiones del arreglo, en este caso solo se muestra 
#### un componente dado que el arreglo es de una sola dimensión


#### Arreglos de más de una dimensión.

#### Hasta ahora solo vimos vectores que son arreglos de una sola dimension, sin embargos en 
#### Julia, puedes definir arreglos de N dimensiones

#### A los arreglos de 2 dimensiones también se les conoce como Matrices, se pueden inicializar 
#### con zeros o números aleatorios o con unos (ones)


ones(1,1)  #Crea una matriz de 1x1 de puros unos

zeros(2,2) ### Crea una matriz de 2*2 compuesta por zeros

rand(3,3) #### Crea una matriz de 3*3 Compuesta por numeros aleatorios,

#### Las matrices no necesariamente deben de ser cuadradas, por Ejemplo

ones(1,3)

zeros(2,3)

rand(3,2)

#### El mismo procedimeinto anteriors ( "Punto antes del operador"), se utiliza
#### para hacer operaciones

A_mat = ones(1,3)

A_mat.+5

A_mat.-4

A_mat.*10

A_mat./2

B_mat = 4 .* ones(1,3)

B_mat.^2



#### Apartado Performance, mientas mas grande sea la matriz más tiempo tomara en crearse/ejecutar

@time rand(2,2)
@time rand(200,200)
@time rand(2000,2000)
@time D =rand(20000,20000)

@time D.^3


##### Del mismo modo y al igual que los vectores se puede hallar extraer un valor de la matriz
##### tomando el índice (En este caso un indice de 2 dimensiones, las dimensiones de la matriz)

A = rand(Int8, 5,5)
# A = rand(5,5)
#=
5×5 Matrix{Int8}:
 60   -8  -80    -2  122
  53   16  -57    52  -69
 -21   14   34     2   24
 -87  -49   66  -100  -14
  14  103   39    98   97
=# 

A[2,2]

A[1,4]

A[4,1]

A[2,3]

A[3,2]

#### Tambien se puede seleccionar elementos de la siguiente manera (No recomendado para matrices grandes)

A[1] 
A[2]
A[20]
A[25]


#### Puedo tambien seleccionar un sub Matrix, la cual puede ser un vector (fila,columna)
#### o una matriz

A[1:2,2:3]
#=
2×2 Matrix{Int8}:
 -8  -80
 16  -57
=#
 A[2:4,3]


#### Lo que hago aqui es asociar a la variable A, el valor de una matriz de 2*¨5 compuesta de puros zeros,
#### el resultado es el sigueinte
A[1:2,2:3] .= 0
#2×5 Matrix{Int8}:
# 0  0  0  0  0
# 0  0  0  0  0


B = rand(Int8,10,10)
## B = rand(10,10)
#=
10×10 Matrix{Int8}:
 -34   -69  -104    77    39  -18  -88  -71  -63  -107
 -32   -42  -103    25  -112  -52  -91   95  -63   -73
 -49     4   -10  -103   -49   22  -89   -6  -10   -62
 -93   -36   -45    34   -72  -13   -4   53    6   -99
  81    81   -53    32    45   47   88   51   24   -69
 -61    61  -108   105    74  -83  -29   15  -58   -28
  93   -51     1  -107   123  -46  -94  109   11   -48
 122   101    -3    79    19  -86  -68  121  -48    63
 102   -39    18    37    22  -88  -77  -24  126    -4
  41  -111   107    40   117  -99   86  -43  127  -116
=#

B[1:2:6,3:1:7]

#=
3×5 Matrix{Int8}:
 -80   2  109  -122   -19
  50  25  -83    93  -107
 115  65  -26   103   -96
 =#

 C = copy(B[1:2:6,3:1:7])
 B[1:2:6,3:1:7] .= 0
 ### Asi mismo se pueden alterar los valores de la matriz, seleccionando bien el índice

A = rand(3,3)

#=
3×3 Matrix{Float64}:
 0.263841  0.838363  0.220494
 0.420858  0.33743   0.239701
 0.638864  0.173004  0.936713
 =#

A[1,2] = -120
A[2,1] = 120
A[1,1] = 30

#=
3×3 Matrix{Float64}:
  30.0       -120.0       0.220494
 120.0          0.33743   0.239701
   0.638864     0.173004  0.936713
=#

# Tambien se pueden cambiar secciones enteras de la matriz, como submatrices, filas o columnas

B = zeros(2,2)

A[1:2,2:3] = B
 
A
#=
3×3 Matrix{Float64}:
  30.0       0.0       0.0
 120.0       0.0       0.0
   0.638864  0.173004  0.936713
 =#
 
 #### Operadores de matrices
using LinearAlgebra
 # Determinante 
det(A)
# Traza
tr(A)
# Autovalores
eigvals(A)
# Rango
rank(A)

### También se puede efectuar la Multiplicacion de matrices y demas

# Inicializo 2 matrices
@show A = rand(1,2)
@show B = rand(2,1)

#Esta operacion dará como resultado una matrix de 1 x 1
A*B

## La operacion contraria da como resultado una matrix de 2x2

B*A

# Para trasponer una matriz se utiliza el apostrofe después de esta
### Fijense como uso el comando Copy para que cualquier cambio qeu haga en a
### No afecte a C
C = copy(B')


D = copy(A')  

## Entre matrices del mismo tamaño se pueden hacer operaciones elemento a elemento(Tambien en vectores)

A = rand(3,3)
#=
0.148727  0.440194  0.00286954
 0.839548  0.237007  0.562949
 0.508041  0.627876  0.614979
 =#
B = zeros(3,3)
#=
0.0  0.0  0.0
0.0  0.0  0.0
0.0  0.0  0.0
=#
C = ones(3,3)


@show A.*B
A.*C

inv(A)

#=
0.0  0.0  0.0
0.0  0.0  0.0
0.0  0.0  0.0
=#

#### Introducción a las tuplas

### Tenemos 4 elementos

E1 =["Open", "Macro"]
E2 =["Open", 5]
E3 = ("Open", "Macro")
E4 = ("Open", 5)

typeof(E1)
typeof(E2)
typeof(E3) 
typeof(E4)

### Se puede accede a los elementos de la tupla de la misma manera que los elementos de un arreglo

E3[1]

E3[2]

E3[3]
#####
E5 = ("MACRO","INTERNACIONAL","CUANTITATIVA")

E5_1, E5_2, E5_3 = E5

E5_1

E5_2

E5_3

### Las tuplas son objetos que una vez definidos no se pueden modificar

E5[1] = "La Plata"

#### Los elementos de una tupla también pueden nombrarse y con esto se accede a ellos


tupla_con_nombres = (Animal = "Perro", raza = "Corgi", año_nac  = "1996") # "Named" tuple

#### Se encuentra el tipo de la tupla
typeof(tupla_con_nombres)



# Se llaman a los elementos
tupla_con_nombres.Animal
tupla_con_nombres.raza
tupla_con_nombres.año_nac
E_b , E_c, E_d  = tupla_con_nombres

E_b
E_c
E_d

## La unica manera de añadir informacion a una tupla es mezclándola con otra , para esto se tiene

tupla_color = (Color="Naranja",Ojos="Azules")

Info_Mascota = merge(tupla_con_nombres,tupla_color)



#### Funciones

### Ejemmplo numero 1 hallar el RMSE
n = 20

datos = randn(n)

media = mean(datos)

diferencia= datos .- media

diferencia_al_cuadrado = diferencia.^2

RMSE = sum(diferencia_al_cuadrado)/length(datos)


#Como se hace esto algoritmicamente

#### En este caso se definen las entradas

#### Depende de lo que quieras hace, puede que pases el vector de numeros aleatorios
#### O que la funcion genere los numeros

function modelo1(datos)
  media = mean(datos)
  diferencia = datos .- media
  RMSE = sum(diferencia.^2)
  return RMSE/length(datos)
end

function modelo2(n)
  datos = rand(n)
  media = mean(datos)
  diferencia = datos .- media
  RMSE = sum(diferencia.^2)
  return RMSE/n
end

##### Espacio para elaborar modelos propios






### Comparacion de  funciones ( Cortesía de Juan Cruz)

#### Todas las funciones de aqui, tienen el mismo objetivo la idea es ver
#### de que manera se trabajaría mejor.

### Para esto se definen las funciones y se hace la comparativa entre tiempos 

function generatedata1(n)
    ϵ = zeros(n)
    for i in eachindex(ϵ)
        ϵ[i] = (randn())^2
    end
    return ϵ
end

function generatedata2(n)
    ϵ = randn(n) 
    for i in eachindex(ϵ)
        ϵ[i] = ϵ[i]^2
    end
    return ϵ
end


function generatedata3(n)
    ϵ = randn(n)
    return ϵ.^2
 end


generatedata4(n) = randn(n).^2


@time generatedata1(10);
@time generatedata2(10);
@time generatedata3(10);
@time generatedata4(10);



@time generatedata1(100);
@time generatedata2(100);
@time generatedata3(100);
@time generatedata4(100);


@time generatedata1(1000);
@time generatedata2(1000);
@time generatedata3(1000);
@time generatedata4(1000);


@time generatedata1(10000);
@time generatedata2(10000);
@time generatedata3(10000);
@time generatedata4(10000);



@time generatedata1(100000);
@time generatedata2(100000);
@time generatedata3(100000);
@time generatedata4(100000);




