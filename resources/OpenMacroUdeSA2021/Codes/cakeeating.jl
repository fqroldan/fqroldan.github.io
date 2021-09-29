print("A cake-eating problem\nLoading codes…")

using PlotlyJS, LinearAlgebra

# Para forma cerrada
function seq(n, β, γ, k)
	ρ = β^(1/γ)
	return [k * (1-ρ) * ρ^t for t in 0:n]
end

function make_plots(; N = 250, β = 0.96, γ = 2, k = 1)

	ys = seq(N, β, γ, k)

	sc = [
		bar(x=0:N, y=ys, name = "<i>c<sub>t")
		scatter(x=0:N, y=cumsum(ys), yaxis="y2", name="consumo total")
		]
	
	layout = Layout(
		yaxis2 = attr(overlaying="y1", side="right", range=[0,k]), 
		yaxis1 = attr(range = [0, ys[1]*1.05]),
		title = "Problema de la torta (<i>β</i> = $β, <i>γ</i> = $γ, <i>k</i> = $k)",
		width = 1920*0.5, height = 1080*0.5,
		legend = attr(orientation = "h", x = 0.05),
		xaxis = attr(zeroline = false, gridcolor="#353535"),
		yaxis = attr(zeroline = false, gridcolor="#353535"),
		paper_bgcolor="#1e1e1e", plot_bgcolor="#1e1e1e",
		font_color="white", font_size = 16, 
)

	return plot(sc, layout)
end

# Para resolver
struct CakeEating
	β::Float64
	γ::Float64

	r::Float64

	kgrid::Vector{Float64}

	v::Vector{Float64}
	gc::Vector{Float64}
	gk::Vector{Float64}
end
function CakeEating(;β=0.96, r=0.02, γ=2, Nk = 20)
	kgrid = range(0,1,length=Nk)
	kgrid = max.(1e-8, kgrid)

	v = zeros(Nk)
	gc = zeros(Nk)
	gk = zeros(Nk)

	return CakeEating(β, γ, r, kgrid, v, gc, gk)
end

# Dos métodos pasando la aversión al riesgo o el modelo entero
u(cv, ce::CakeEating) = u(cv, ce.γ)
function u(cv, γ::Number)
	if γ == 1
		return log(cv)
	else
		return cv^(1-γ) / (1-γ)
	end
end

function budget_constraint(kpv, kv, r)
	# La torta de hoy (más intereses) financia el consumo de hoy y la torta de mañana
	c = kv * (1+r) - kpv
	return c
end

function eval_value(jkp, kv, ce::CakeEating)
	# Evalúa la función de valor en estado k cuando el candidado de mañana es el jkp-ésimo
	β, r = ce.β, ce.r
	kpv = ce.kgrid[jkp]

	# Consumo implicado por la restricción de presupuesto
	cv = budget_constraint(kpv, kv, r)

	# Devuelve -Inf si el consumo llega a no ser positivo
	cv > 0 || return cv, -Inf
	
	# Flujo de utilidad por el consumo de hoy
	ut = u(cv, ce)
	
	# Valor de continuación
	vp = ce.v[jkp]

	# Flujo más valor descontado de mañana
	v = ut + β * vp

	return cv, v
end

function opt_value!(jk, ce::CakeEating)
	# Elige la torta de mañana en el jk-ésimo estado
	kv = ce.kgrid[jk]
	
	vp = -Inf
	c_star = 0.0
	k_star = 0.0
	problema = true
	# Recorre todos los posibles valores de la torta de mañana
	for (jkp, kpv) in enumerate(ce.kgrid)
		# Consumo y valor de ahorrar kpv
		cv, v = eval_value(jkp, kv, ce)

		# Si el consumo es positivo y el valor es más alto que el más alto que encontré hasta ahora, reemplazo
		if cv > 0 && v > vp
			# Actualizo el "mejor valor" con el que acabo de calcular
			vp = v
			k_star = kpv
			problema = false
			c_star = cv
		end
	end

	# Si en cualquier momento entré en el "if" de arriba, va a ser falso que hubo problemas, si no...
	if problema == true
		throw(error("Hay problemas!!"))
	end

	return k_star, vp, c_star
end

function vfi_iter!(new_v, ce::CakeEating)
	# Una iteración de la ecuación de Bellman
	# Recorro los estados posibles para hoy
	for jk in eachindex(ce.kgrid)
		
		# Calculo el mejor ahorro, consumo, y valor en el estado kv
		k_star, vp, c_star = opt_value!(jk, ce)
		
		# Guardo en new_v y las funciones de política directamente
		new_v[jk] = vp
		ce.gc[jk] = c_star
		ce.gk[jk] = k_star
	end
end

function vfi!(ce::CakeEating; tol = 1e-8, maxiter = 2000, verbose = true)
	# Itera hasta convergencia de la ecuación de Bellman
	# Preparo un vector para guardar la actualización del guess
	new_v = similar(ce.v)

	dist = 1+tol
	iter = 0

	while dist > tol && iter < maxiter
		iter += 1

		# Una iteración
		vfi_iter!(new_v, ce)

		# Distancia entre el guess viejo y el nuevo
		dist = norm(new_v - ce.v) / (1+norm(ce.v))

		# Actualizo cada elemento del guess con la nueva función de valor
		ce.v .= new_v
	end
	verbose && print("Iteration $iter. Distance = $dist\n")
	dist < tol || print("✓")
end

print(" ✓\nConstructor: CakeEating(;β=0.96, r=0.02, γ=2, Nk = 20)\nSolver: vfi!(ce::CakeEating)\n")