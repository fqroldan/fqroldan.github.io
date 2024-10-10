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
		bar(x=0:N, y=ys, name = "<i>c<sub>t", marker_line_width = 0)
		scatter(x=0:N, y=cumsum(ys), yaxis="y2", name="consumo total")
		]
	
	layout = Layout(
		title = "Problema de la torta (<i>β</i> = $β, <i>γ</i> = $γ, <i>k</i> = $k)",
		width = 1920*0.5, height = 1080*0.5,
		legend = attr(orientation = "h", x = 0.05),
		xaxis = attr(zeroline = false, gridcolor="#434343"),
		yaxis1 = attr(range = [0, ys[1]*1.05], zeroline = false, gridcolor="#434343"),
		yaxis2 = attr(overlaying="y1", side="right", range=[0,k*1.061], zeroline = false, gridcolor="#434343", tick0 = 0, dtick = 0.25), 
		paper_bgcolor="#272929", plot_bgcolor="#272929",
		font_color="#F8F1E9", font_size = 18, 
	)

	return plot(sc, layout)
end

# savefig(p1, "Images/cake_1_dark.pdf", height = 500, width = 1000)

# Para resolver
struct CakeEating
	pars::Dict{Symbol, Float64}

	kgrid::Vector{Float64}

	v::Vector{Float64}
	gc::Vector{Float64}
	gk::Vector{Float64}
end
function CakeEating(;β=0.96, k0 = 1, r=0.02, γ=2, Nk = 20)
	kgrid = range(1e-6,k0,length=Nk)

	pars = Dict(:β => β, :r => r, :γ => γ)

	v = zeros(Nk)
	gc = similar(v)
	gk = similar(v)

	return CakeEating(pars, kgrid, v, gc, gk)
end

# Dos métodos pasando la aversión al riesgo o el modelo entero
u(cv, ce::CakeEating) = u(cv, ce.pars[:γ])
function u(cv, γ::Number)
	if γ == 1
		return log(cv)
	else
		return (cv^(1-γ) - 1) / (1-γ)
	end
end

function budget_constraint(kpv, kv, r)
	# La torta de hoy (más intereses) financia el consumo de hoy y la torta de mañana
	c = kv * (1+r) - kpv
	return c
end

function eval_value(jkp, kv, ce::CakeEating)
	# Evalúa la función de valor en estado k cuando el candidado de mañana es el jkp-ésimo
	β, r = ce.pars[:β], ce.pars[:r]
	kpv = ce.kgrid[jkp]

	# Consumo implicado por la restricción de presupuesto
	cv = budget_constraint(kpv, kv, r)

	# Devuelve -Inf si el consumo llega a no ser positivo
	if cv <= 0
		return cv, -Inf
	end
	# cv > 0 || return cv, -Inf
	
	# Flujo de utilidad por el consumo de hoy
	ut = u(cv, ce)
	
	# Valor de continuación
	vp = ce.v[jkp]

	# Flujo más valor descontado de mañana
	v = ut + β * vp

	return cv, v
end

function opt_value(jk, ce::CakeEating)
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
		k_star, vp, c_star = opt_value(jk, ce)
		
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
		dist = norm(new_v - ce.v) / max(1,norm(ce.v))

		# Actualizo cada elemento del guess con la nueva función de valor
		ce.v .= new_v
	end
	verbose && print("Iteration $iter. Distance = $dist\n")
	dist < tol && print("✓")
end

print(" ✓\nConstructor: CakeEating(;β=0.96, r=0.02, γ=2, Nk = 20)\nSolver: vfi!(ce::CakeEating)\n")

