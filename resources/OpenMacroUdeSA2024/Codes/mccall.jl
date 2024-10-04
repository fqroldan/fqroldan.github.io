print("McCall, J. J. 'Economics of Information and Job Search' The Quarterly Journal of Economics, 1970, vol. 84, issue 1, 113-126\n")
print("Loading codes… ")

using Distributions, LinearAlgebra, StatsBase, PlotlyJS

mutable struct McCall
	β::Float64
	γ::Float64

	b::Float64

	wgrid::Vector{Float64}
	pw::Vector{Float64}

	w_star::Float64
	v::Vector{Float64}
end

function McCall(;
	β = 0.96,
	γ = 0,
	b = 1,
	μw = 1,
	σw = 0.05,
	Nσ = 0,
	wmin = 0.5,
	wmax = 2,
	Nw = 500)

	if Nσ > 0
		wmin = μw - Nσ * σw
		wmax = μw + Nσ * σw
	end

	wgrid = range(wmin, wmax, length=Nw)

	w_star = first(wgrid)

	d = Normal(μw, σw)

	pw = [pdf(d, wv) for wv in wgrid]
	# pw = pdf.(d, wgrid)

	pw = pw / sum(pw)

	v = zeros(Nw)

	return McCall(β, γ, b, wgrid, pw, w_star, v)
end

function u(c, mc::McCall)
	γ = mc.γ

	if γ == 1
		return log(c)
	else
		return (c^(1-γ) - 1) / (1-γ)
	end
end

function R(w, mc::McCall)
	## Valor de aceptar una oferta w: R(w) = u(w) + β R(w)
	β = mc.β
	return u(w, mc) / (1-β)
end

function E_v(mc::McCall)
	## Valor esperado de la función de valor integrando sobre la oferta de mañana
	Ev = 0.0
	for jwp in eachindex(mc.wgrid)
		Ev += mc.pw[jwp] * mc.v[jwp]
	end
	return Ev
end

function update_v(ac, re, EV=false)
	## Actualizar la función de valor con max(aceptar, rechazar) si EV es falso o usando la forma cerrada con el extreme value si EV es verdadero
	if EV
		χ = 0.1
		### Con Extreme Value type 1
		# Probabilidad de aceptar
		prob = exp(ac/χ)/(exp(ac/χ)+exp(re/χ))
		V = χ * log( exp(ac/χ) + exp(re/χ) )

		return V
	else
		return max(ac, re)
	end
end

function vf_iter!(new_v, mc::McCall)
    flag = 0
	## Una iteración de la ecuación de Bellman

	# El valor de rechazar la oferta es independiente del estado de hoy
	rechazar = u(mc.b, mc) + mc.β * E_v(mc)
	for (jw, wv) in enumerate(mc.wgrid)
		# El valor de aceptar la oferta sí depende de la oferta de hoy
		aceptar = R(wv, mc)

		# Para una oferta w, v(w) es lo mejor entre aceptar y rechazar
		new_v[jw] = update_v(aceptar, rechazar)

		# El salario de reserva es la primera vez que aceptar es mejor que rechazar
		if flag == 0 && aceptar >= rechazar
			mc.w_star = wv
			flag = 1
		end
	end
end

function vfi!(mc::McCall; maxiter = 2000, tol = 1e-8, verbose=true)
	dist, iter = 1+tol, 0
	new_v = similar(mc.v)
	while dist > tol && iter < maxiter
		iter += 1
		vf_iter!(new_v, mc)
		dist = norm(mc.v - new_v)
		mc.v .= new_v # volcar lo de new_v hacia mc.v, lugar a lugar
		if verbose
			print("Iter $iter: dist = $dist\n")
		end
	end
	if verbose
		if iter == maxiter
			print("Abandoné después de ")
		else
			print("Terminé en ")
		end
		print("$iter iteraciones.\nDist = $dist\n")
	end
end

function make_plots(mc::McCall)

    aceptar_todo = [R(wv, mc) for wv in mc.wgrid]
    at = scatter(x=mc.wgrid, y=aceptar_todo, line_color="#f97760", name="u(w) / (1-β)")

    rechazar_todo = [u(mc.b, mc) + mc.β * E_v(mc) for _ in mc.wgrid]
    rt = scatter(x=mc.wgrid, y=rechazar_todo, line_color="#0098e9", name="u(b) + β ∫v(z) dF(z)")

    opt = scatter(x=mc.wgrid, y=mc.v, line_color="#5aa800", line_width=3, name="v(w)")
	# opt2 = scatter(x=mc.wgrid, y = max.(aceptar_todo, rechazar_todo), name = "max")

	χ = 0.1
	opt2 = [ χ * log( exp(aceptar_todo[jw] / χ) + exp(rechazar_todo[jw] / χ) ) for jw in eachindex(mc.wgrid)]

	opts = scatter(x=mc.wgrid, y = opt2, name = "v(w) con log-sum-exp")

    traces = [at, rt, opt]

    shapes = [vline(mc.w_star, line_dash="dot", line_color="#818181")]

    annotations = [attr(x=mc.w_star, y=0, yanchor="top", yref="paper", showarrow=false, text="w*")]

    layout = Layout(shapes=shapes,
        annotations=annotations,
        title="Value function in McCall's model",
        width=1920 * 0.5, height=1080 * 0.5,
        legend=attr(orientation="h", x=0.05),
        xaxis=attr(zeroline=false, gridcolor="#434343"),
        yaxis=attr(zeroline=false, gridcolor="#434343"),
        paper_bgcolor="#272929", plot_bgcolor="#272929",
        font_color="#F8F1E9", font_size=16,
        font_family="Lato",
        hovermode="x",
    )

    plot(traces, layout)
end

function simul(mc::McCall; maxiter = 2000, verbose::Bool=true)
	flag = 0
	t = 0
	PESOS = Weights(mc.pw)
	while flag == 0 && t < maxiter
		t += 1
		wt = sample(mc.wgrid, PESOS)
		verbose && print("Salario en el período $t: $wt. ")
		verbose && sleep(0.1)
		wt >= mc.w_star ? flag = 1 : (verbose && println("Sigo buscando"))
	end

	(verbose && flag == 1) && println("Oferta aceptada en $t períodos")
	
	return t
end


print("✓\nConstructor mc = McCall(; β = 0.96, γ = 0, b = 1, μw = 1, σw = 0.05, wmin = 0.5, wmax = 2, Nw = 50)\n")
print("Main loop vfi!(mc)\n")