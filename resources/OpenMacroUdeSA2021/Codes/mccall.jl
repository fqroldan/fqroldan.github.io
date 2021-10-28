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
	Nw = 50)

	if Nσ > 0
		wmin = μw - Nσ * σw
		wmax = μw + Nσ * σw
	end

	wgrid = range(wmin, wmax, length=Nw)

	w_star = first(wgrid)

	d = Normal(μw, σw)

	pw = [pdf(d, wv) for wv in wgrid]

	pw = pw / sum(pw)

	v = zeros(Nw)

	return McCall(β, γ, b, wgrid, pw, w_star, v)
end

function u(c, mc::McCall)
	γ = mc.γ

	if γ == 1
		return log(c)
	else
		return c^(1-γ) / (1-γ)
	end
end

function R(w, mc::McCall)
	## Valor de aceptar una oferta w: R(w) = u(w) + β R(w)
	β = mc.β
	return u(w, mc) / (1-β)
end

function E_v(mc::McCall, θ = 0)
	## Valor esperado de la función de valor integrando sobre la oferta de mañana
	Ev = 0.0
	for jwp in eachindex(mc.wgrid)
		if θ == 0
			Ev += mc.pw[jwp] * mc.v[jwp]
		else
			Ev += mc.pw[jwp] * exp(-θ * mc.v[jwp])
		end
	end
	if θ > 0
		Ev = -1/θ * log(Ev)
	end
	return Ev
end

function update_v(ac, re, EV)
	## Actualizar la función de valor con max(aceptar, rechazar) si EV es falso o usando la forma cerrada con el extreme value si EV es verdadero
	if EV
		χ = 2
		### Con Extreme Value type 1
		# Probabilidad de aceptar
		# prob = exp(ac/χ)/(exp(ac/χ)+exp(re/χ))
		# V = χ * log( exp(ac/χ) + exp(re/χ) )
		# return prob * ac + (1-prob) * re

		### Con Normal
		d = Normal(0,χ)
		prob = cdf(d, ac-re)
		cond_χ = truncated(d, re-ac, Inf) |> mean
		V = (1-prob) * re + prob * ac + cond_χ * prob
		return V
	else
		return max(ac, re)
	end
end

function vf_iter!(new_v, mc::McCall, θ = 0, flag = 0; EV=true)
	## Una iteración de la ecuación de Bellman

	# El valor de rechazar la oferta es independiente del estado de hoy
	rechazar = u(mc.b, mc) + mc.β * E_v(mc, θ)
	for (jw, wv) in enumerate(mc.wgrid)
		# El valor de aceptar la oferta sí depende de la oferta de hoy
		aceptar = R(wv, mc)

		# Para una oferta w, v(w) es lo mejor entre aceptar y rechazar
		new_v[jw] = update_v(aceptar, rechazar, EV)

		# El salario de reserva es la primera vez que aceptar es mejor que rechazar
		if flag == 0 && aceptar >= rechazar
			mc.w_star = wv
			flag = 1
		end
	end
end

function vfi!(mc::McCall, θ = 0; maxiter = 2000, tol = 1e-8, verbose=true)
	dist, iter = 1+tol, 0
	new_v = similar(mc.v)
	while dist > tol && iter < maxiter
		iter += 1
		vf_iter!(new_v, mc, θ)
		dist = norm(mc.v - new_v)
		mc.v .= new_v
	end
	if verbose
		if iter == maxiter
			print("Stopped after ")
		else
			print("Finished in ")
		end
		print("$iter iterations.\nDist = $dist\n")
	end
end

function simul(mc::McCall, flag = 0; maxiter = 2000, verbose::Bool=true)
	t = 0
	PESOS = Weights(mc.pw)
	while flag == 0 && t < maxiter
		t += 1
		wt = sample(mc.wgrid, PESOS)
		verbose && print("Salario en el período $t: $wt. ")
		verbose && sleep(0.1)
		wt >= mc.w_star ? flag = 1 : verbose && println("Sigo buscando")
	end
	
	(verbose && flag == 1) && println("Oferta aceptada en $t períodos")
	
	return t
end

function dist_T(mc::McCall, K = 100)
	Tvec = Vector{Int64}(undef, K)
	for jt in eachindex(Tvec)
		Tvec[jt] = simul(mc, verbose=false)
	end
	Tvec
end

print("✓\nConstructor mc = McCall(; β = 0.96, γ = 0, b = 1, μw = 1, σw = 0.05, wmin = 0.5, wmax = 2, Nw = 50\n")
print("Main loop vfi!(mc)\n")