#=
3er Code Camp de MacroEconomía Internacional
20/09/2022

Profesor : Francisco Roldan
Asistente: Francisco J. Guerrero

Temas : Funciones y  Gráficos



=#






#= Funciones 
Las funciones en Julia permiten la ejercucion de ciertos procesos,
permiten el uso de algoritmos o fragmentos de código
=#

#=
La manera de inicializar una función en Julia es de la siguiente manera
1.- Se usa la palabra function
2.- Se pone el nombre de la función, 
3.- Luego de esto se abren los paréntesis y se pone los argumentos
     que recibira la función
=#


function mayor_a_5(x) # Nombre de la función
    x > 5 #Proceso de la función
end

#= 
En este caso inicialize la funcion mayor_a_5 la cual evalua
 si un número es mayor a cierta cantidad, en este caso 
 la cantidad esta fija
=#

mayor_a_5(3)

mayor_a_5(4)

mayor_a_5(6)

mayor_a_5(7)



#= 
La función, recibe un argumento  y ejecuta una tarea especifica. 
En este caso si queremos que la cantidad a comparar sea variable, 
esta puede ser llamada como como otro argumento
=#

function mayor_x_que_y(x,y)
    x > y
end
# Nota ("Fijense en la palabra methods")
# Notese como los parentesis ya no tiene uno, sino 2 argumentos x e y

mayor_x_que_y(5,4)

mayor_x_que_y(4,5)

mayor_x_que_y(5)

mayor_x_que_y(5,5.2)
# La funcion permitió comparar un numero entero con un número decimal!

# Excepcionalmente se pueden comparar letras, siguiendo el orden del diccionario
mayor_x_que_y("g","fe")

#=
 El script se ejecutó correctamente, devolviendo las respuestas adecuadas,
  ahora tambien Julia nos permite  que se pueda llamar a la función, 
  mediante un sólo argumento

  
    mayor_x_que_y(x)
 # Probar esto en consola debería dar error

Para lograr esto se modifica  la función para que algunos de sus arugmentos
 tengan un valor inicializado por defecto en caso no le sean asignados
=#


function mayor_x_que_y(x, y =5)
    x > y
end
# Toma nota como cambios "methods "
mayor_x_que_y(4)

mayor_x_que_y(4,5)

mayor_x_que_y(4)

mayor_x_que_y(6)

#= 
Si se asigna un valor por defecto a todas las variables también, se puede llamar
a la función sin especificarle ningún argumento.
=#

function mayor_x_que_y(x =4, y=3)
    x > y
end

mayor_x_que_y()

#= 
El ejemplo propuesto solo compara si una cantidad es mayor a otra, 
abajo se listan más ejemplos.
=#
suma(x=5,y=10)

function suma(x,y)
    x+y #Cuerpo de la función
end


function division(x,y)
    x/y
end

function resta(x,y)
    x-y
end

function multiplicacion(x,y)
    x*y
end

#= 
En lugar de definir varias funciones para tareas especificas, se podria adicionar 
un argumento adicional a una función que tome como argumento 2 variables
y este arguemnto será una especie de selector
=#

function operacion(x= 5,y = 5,operador ="+")
    if operador == ">"
        return x > y
    end
    if operador == "<"
        return x < y
    end
    if operador == "=="
        return x == y
    end
    if operador == "<="
        return x <= y
    end
    if operador == ">="
        return x >= y
    end
    if operador == "+"
        return x + y
    end
    if operador == "*"
        return x * y
    end
    if operador == "-"
        return x - y
    end
    if operador == "/"
        return x / y
    end
    if operador == "^"
        return x ^ y
    end
end

# Modo normal, tomando el valor por defecto del selector
operacion(5,4)

# Cambiando el tercer arugmento
operacion(5,4,"*")

# Esta función retorna un NoneType, es decir nada dado que 
# 20 no cae en ninguna categorización dentro de las opciones de operador
operacion(5,4,20)

#= 
En caso quiera evitar esto, establezo que tipo de argumento debe recibir 
el selector, en este caso lo condiciono a que no reciba números, sino 
cadenas de texto.
=#

function comparacion(x=4,y=5,comp::String = "<")
    if comp == "<"
        return x < y
    end
    if comp == "=="
        return x == y
    end
    if comp == ">" 
        return x > y
    end
end

#Hace la comparacion correctamente
comparacion(4,5,"==")


comparacion(4,5,3)

#=
Podemos ver como la segunda opción bota un error a consola
en el cual dice que no existe un método que pueda manejar 
el tipo de valor que recibió, además de esto te da las opciones 
más cercanas
=#



#= 
Poner un punto y coma dentro de los parentesis de la función
y escribir argumentos me permite llamarlos a estos por su nombre
(Este es el ejemplo clásico de una NamedTuple), al llamarlos por
su nombre puedo llamarlos en el orden que guste,
Si hay otros agumentos que están antes del punto y coma y no tienen
valor inicializado por defecto, se deben especificar al momento de 
llamar la función.
En el curso veran mucho de estas funciones, dado que los modelos
trabajan sobre parametros y se evalua la dinámica del modelo bajo
el cambio de estos mismos.
=#
function comparacion_a_mayor_que_b(;a = 5, b=4)
    a > b
end
# Fijense la palabra metodos 

comparacion_a_mayor_que_b(a=5,b = 6)

comparacion_a_mayor_que_b(b=6, a=5)

#=
Julia pemrite que las funciones tengan multiple dispatch, lo cual es que
las funciones tengan diferentes comportamientos según el tipo de dato que reciben,
para esto se debe especificar que proceso quiere que se ejecute respecto a los tipos
de argumento que recibe la función, para lograr esto se vuelve a escirbir la funcion
 cambiando el proceso y considerando el diferente tipo en el argumento
=#

function cuadrado(x)
    x^2
end
function cuadrado(x::Array{Int64,1})
    x.^2
end
function cuadrado(x::String)
    "El argumento ingresado no es un número"
end


# Llamar ala función Methods permite saber la cantidad de métodos de la función.
methods(cuadrado)

cuadrado(5)

cuadrado([5,2])


cuadrado("Test_String")


#=
Ojo que el método de multiple dispatch, también gnera multiples métodos cuando cambian los numeros de arguementos
de la función

=#



#= Adicionales 
Las funciones también pueden definirse como comandos de una sola línea
, por ejemplo

f(x) = x.^2

=#
f(x,y) = x^y
f(x::Int64, y::Float64) = x^y
f(x::Float64, y::Float64) = x^y
f(x::Array{Int64,1}, y::Int64) = x.^y
f(x::Array{Int64,1}, y::Float64) = x.^round(y)


g(x, y::Float64 =2.0) = x^y
g(x::Array{Int64,1}, y = 2) = x.^y
g(x::Array{Float64,1}, y =2) = x.^y


#### Asi mismo una funcion puede retornar multiples argumentosç
#### Estos se retornan en forma de una tupla

function multiples_respuestas(;x::Int64)
    cuadrado = x^2
    cubo = x^3
    return cuadrado, cubo
end

response = multiples_respuestas(x=4)
quad, cubo = multiples_respuestas(x=4)
#### Como se puede ver la respuesta de la función es una tupla, y al igual que las tuplas
#### puedo seleccionar cada elemento 

quad
cubo

#### Ejemplo graficando un ruido blanco #####
#### Para graficar un ruido blanco se sigue el sigueinte proceso
# Se llama a la librería PlotlyJS para que puedan usarse las fuciones de
# la librería.
# Se establece la variable n la cual es el tamaño del  arreglo
# Se genera un arreglo de número aleatorios, tomando como argumento
# n en la función randn.
using PlotlyJS
using Random
using LinearAlgebra, Expectations, NLsolve, Roots, Random, Parameters
using Distributions, Statistics, PlotlyJS

n = 100
ϵ = randn(n)
plot(ϵ)
plot(1:n, ϵ)

X_scatter = randn(100)
Y_scatter = randn(100)

X_contour = collect(1:100)
Y_contour = collect(1:100)

Z = randn(100,100)

#= 
Para generar un objeto Histograma , lo escirob dentro de la función 
histogram, con esto se introduce el argumento que es la variable 
de la cual se quire mostrar especificandola así
histogram(x = variable)
Luego de esto se procede a Plotear.
=#
grafico_hist_100 = histogram(x = randn(100), opacity=0.75)
histogram(randn(100))

plot(grafico_hist_100)


grafico_hist_1000 = histogram(x = randn(1000), opacity=0.75)


plot(grafico_hist_1000)


grafico_hist_10000 = histogram(x = randn(10000), opacity=0.75)


plot(grafico_hist_10000)


grafico_hist_100000 = histogram(x = randn(100000), opacity=0.75)


plot(grafico_hist_100000)

#=
Asi mismo el comando Layout, acompañando al objeto a plotear te 
permite ponerle títulos a los gráficos y demás elementos.
=#
plot([grafico_hist_100000], Layout(title="Distribución de Bell",
                                    xaxis_title = "Valor",
                                    yaxis_title = "Cantidad"))

#= 
Asi mismo para graficar variables se utiliza la funcion scatter,
bien puede servir para graficar la evolcuon de una línea en un vector_rep
como :  scatter(x=Variable), o graficar la evolción de una variable respecto 
a otra :   scatter(x= Variable_1, y = Variable_2)
=#



plot_consumo=scatter(x=1:100,y=X_scatter,name="A = 1.5")
plot_torta=scatter(x=1:100,y=Y_scatter,name="A = 1.6")

#=
En ciertos casoas puedes plotear 2 objetos de manera conjunta,
este es el caso en elcual se plotean 2 variables, para esto 
pongo ambas juntas como un arreglo de 2 vectores.
=#

A = plot([plot_consumo, plot_torta], Layout(title="C y A", xaxis_title="Trabajo",yaxis_title = "Producto"))
   

#= 
Julia también me permite graficar contornos, para esto
o bien se especifica solo la variable Z , o se especfican las 3 variables
=#

grafico_contorno = contour(x=1:100,y=1:100,z= Z',colorscale="inferno",name="Contorno 1")



grafico_contorno = contour(x=1:100,y=1:100,z= Z',colorscale="inferno",name="Contorno 2",
contours=attr(
        coloring ="heatmap",
        showlabels = true, # show labels on contours
        labelfont = attr( # label font properties
            size = 12,
            color = "white",
        )))
plot(grafico_contorno)

grafico_hist_100 = histogram(x = randn(100), opacity=0.75)


plot(grafico_hist_100)


grafico_hist_1000 = histogram(x = randn(1000), opacity=0.75)


plot(grafico_hist_1000)


grafico_hist_10000 = histogram(x = randn(10000), opacity=0.75)


plot(grafico_hist_10000)


grafico_hist_100000 = histogram(x = randn(100000), opacity=0.75)


plot(grafico_hist_100000)

plot([grafico_hist_100000], Layout(title="Distribución del capital",
                                    xaxis_title = "Valor",
                                    yaxis_title = "Cantidad"))


#=
La librería plotly también te permite generar superficies en 3d mediante la 
función surface
La forma de declarar la función es muy similar a la fomra de lso contornos
=#



Z_3d = randn(100,100)

layout = Layout(
title="Grafico 3D",
autosize=false,
width=500,
height=500
)
plot(surface(z=Z_3d), layout)

f(x,y) = (x-5)^2+(y-5)^2

# De este modo se puede generar una matriz, haciendo broadcastign de la función
z_esfera = f.(collect(1:10),collect(1:10)')

[2,5].^2



layout_2 = Layout(
title="Hiperplano",
autosize=false,
width=500,
height=500
)

plot(surface(z=z_esfera), layout_2)



g_2(x,y) = 6-x^2 -y^2

z_t = g_2.(collect(-5:5),collect(-5:5)')

superficie = surface(z=z_t,contours_z=attr(show=true,
usecolormap=true,
        highlightcolor="limegreen",project_z=true))


plot(superficie)



plot(surface(z=z_t,contours_z=attr(show=true,
usecolormap=true,
        highlightcolor="limegreen",project_z=true)), layout_2)





#=

Ejemplo de clase 
Calculo de figuras del mundial

Se replica el ejemplo desarrollado por el PHD Federico Tiberti

Para esto se hacen 3 funciones

Una funcion principal (Album) que itera sobre los sobres otorgados y calcula si 
se lleno todo el álbum

2 Funciones secundarias (completo, nfiguras) para contar las filas y comprobar si todos los jugadores
llenaron el album


=#




function Album(N::Int64 = 100, Fig::Int64 =670, rep::Int64= 1000, sobres_totales::Int64 = 1000 )
    #=
     Inicialize la función, especificnado los tipos de arguemnto que debe recibir
     N = Numero de jugadores
     Fig = Numero de Figuras
     rep = Numero de repticiones para hallar probabilidad
     sobres_totales = Sobres totoales de la simulación.
     =#
     # Se genera el vector respuesta que se refiere a la probabilidad de llenar un album 
     # con un vector que se relaciona a los sobres abiertos.
    response = zeros(sobres_totales)
    for K = 1:sobres_totales
        sobres = K
        vector_rep = zeros(rep)
        for repe in 1:rep
            # Se regenera la matriz de figuras cada vez que hace una repeticion
            # Si no se hace esto, se traerian los rsutlados de la repeticion anterior
            # lo cual afectaría al resultado
            Figs = zeros(N,Fig)   
            for i = 1:sobres
                for j =1:N
                    # Se itera sobre cada jugador y se halla las figuras que le
                    # tocaron, como cada sobre tiene 5 figuras se declaran 5 
                    # variables, cada una responde al índice de la figura que le 
                    # salió en el sobre, esto te permite tener figuras repetidas.
                    p1 = rand(1:Fig)
                    p2 = rand(1:Fig)
                    p3 = rand(1:Fig)
                    p4 = rand(1:Fig)
                    p5 = rand(1:Fig)
                
                    Figs[j,p1] += 1
                    Figs[j,p2] += 1
                    Figs[j,p3] += 1
                    Figs[j,p4] += 1
                    Figs[j,p5] += 1
                end
            end
            # Se guarda el resultado de la repeticion
            vector_rep[repe] =  completo(nfiguras(Figs),N)
        end
        # Se promedia y se hallan las probabilidades
        response[sobres] = mean(vector_rep)    
    end
    # return sobres,Figs
    return response
end

# Funicones auxiliares a la función principal
function completo(Vector_f, val)
    for i in Vector_f
        if i < val 
            return false
        end
    end
    return true
end

function nfiguras(matriz)
    Figuras = size(matriz)[2]

    Vector_figuras = zeros(size(matriz)[2])
    for i in 1:Figuras
        Vector_figuras[i] = sum(matriz[:,i])
    end
    return Vector_figuras
end


## Analisis con diferentes numeros de jugadores
response_1 = Album(1,670,100,1000)
response_2 = Album(2,670,100,1000)
response_3 = Album(3,670,100,1000)
response_4 = Album(4,670,100,1000)
response_5 = Album(5,670,100,1000)
response_6 = Album(6,670,100,1000)
response_7 = Album(7,670,100,1000)
response_8 = Album(8,670,100,1000)
response_9 = Album(9,670,100,1000)
response_10 = Album(10,670,100,1000)
response_11 = Album(11,670,100,1000)
response_12 = Album(12,670,100,1000)


# Grafica de la respuesta
plot(scatter(x=1:1000,y=response_1,mode="markers",name="1 Participantes"))
plot(scatter(x=1:1000,y=response_2,mode="markers",name="2 Participantes"))
plot(scatter(x=1:1000,y=response_3,mode="markers",name="3 Participantes"))

plot(scatter(x=1:2000,y=response_4,mode="markers",name="4 Participantes"))
plot(scatter(x=1:2000,y=response_5,mode="markers",name="5 Participantes"))
plot(scatter(x=1:2000,y=response_6,mode="markers",name="6 Participantes"))

plot(scatter(x=1:2000,y=response_7,mode="markers",name="7 Participantes"))
plot(scatter(x=1:2000,y=response_8,mode="markers",name="8 Participantes"))
plot(scatter(x=1:2000,y=response_9,mode="markers",name="9 Participantes"))

plot(scatter(x=1:2000,y=response_10,mode="markers",name="10 Participantes"))
plot(scatter(x=1:2000,y=response_11,mode="markers",name="11 Participantes"))
plot(scatter(x=1:2000,y=response_12,mode="markers",name="12 Participantes"))
