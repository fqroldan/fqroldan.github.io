print("McCall, J. J. 'Economics of Information and Job Search' The Quarterly Journal of Economics, 1970, vol. 84, issue 1, 113-126\n")
print("Loading codes… ")

using Distributions, LinearAlgebra, PlotlyJS

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
	wmin = 0.5,
	wmax = 2,
	Nw = 50)

	wgrid = range(wmin, wmax, length=Nw)

	w_star = first(wgrid)

	d = Normal(μw, σw)

	pw = [pdf(d, wv) for wv in wgrid]

	pw = pw / sum(pw)

	v = zeros(Nw)

	return McCall(β, γ, b, wgrid, pw, w_star, v)
end

function u(mc::McCall, c)
	γ = mc.γ

	if γ == 1
		return log(c)
	else
		return c^(1-γ) / (1-γ)
	end
end

function R(mc::McCall, w)
	β = mc.β

	return u(mc, w) / (1-β)
end

function E_v(mc::McCall)
	Ev = 0.0
	for (jwp, wpv) in enumerate(mc.wgrid)
		Ev += mc.pw[jwp] * mc.v[jwp]
	end
	return Ev
end

E_v2(mc::McCall) = sum([mc.pw[jwp]*mc.v[jwp] for (jwp,wpv) in enumerate(mc.wgrid)])

E_v3(mc::McCall) = mc.pw'*mc.v

function update_v(ac, re, EV)
	if EV
		κ = 10
		prob = exp(ac/κ)/(exp(ac/κ)+exp(re/κ))
		return prob * ac + (1-prob) * re
	else
		return max(ac, re)
	end
end

function vf_iter(mc::McCall, flag = 0; EV=false)
	new_v = similar(mc.v)
	for (jw, wv) in enumerate(mc.wgrid)
		aceptar = R(mc, wv)
		rechazar = u(mc, mc.b) + mc.β * E_v(mc)

		new_v[jw] = update_v(aceptar, rechazar, EV)

		if flag == 0 && aceptar >= rechazar
			mc.w_star = wv
			flag = 1
		end
	end

	return new_v
end
function vf_iter!(new_v, mc::McCall, flag = 0; EV=false)
	rechazar = u(mc, mc.b) + mc.β * E_v(mc)
	for (jw, wv) in enumerate(mc.wgrid)
		aceptar = R(mc, wv)

		new_v[jw] = update_v(aceptar, rechazar, EV)

		if flag == 0 && aceptar >= rechazar
			mc.w_star = wv
			flag = 1
		end
	end
end

function vfi2!(mc::McCall; maxiter = 200, tol = 1e-8)
	dist, iter = 1+tol, 0
	new_v = similar(mc.v)
	while dist > tol && iter < maxiter
		iter += 1
		vf_iter!(new_v, mc)
		dist = norm(mc.v - new_v)
		mc.v = copy(new_v)
	end
	print("Finished in $iter iterations. Dist = $dist")
end

function vfi!(mc::McCall; maxiter = 200, tol = 1e-6)
	dist, iter = 1+tol, 0
	while dist > tol && iter < maxiter
		iter += 1
		new_v = vf_iter(mc)
		dist = norm(mc.v - new_v)
		mc.v = new_v
	end
	print("Finished in $iter iterations. Dist = $dist")
end

function simul(mc::McCall, flag = 0; maxiter = 2000, verbose::Bool=true)
	t = 0
	while flag == 0 && t < maxiter
		t += 1
		jw = findfirst(cumsum(mc.pw) .>= rand())
		wt = mc.wgrid[jw]
		verbose && print("Salario en el período $t: $wt. ")
		wt >= mc.w_star ? flag = 1 : verbose && println("Sigo buscando")
	end
	verbose || flag == 1 && return t
	flag == 1 && println("Oferta aceptada en $t períodos")
end

function dist_T(mc::McCall, K = 100)
	Tvec = Vector{Int64}(undef, K)
	for jt in eachindex(Tvec)
		Tvec[jt] = simul(mc, verbose=false)
	end
	Tvec
end

function make_plots(mc::McCall)

	aceptar_todo = [R(mc, wv) for wv in mc.wgrid]
	at = scatter(x=mc.wgrid, y=aceptar_todo, line_color="#f97760", name = "u(w) / (1-β)")

	rechazar_todo = [u(mc, mc.b) + mc.β * E_v(mc) for wv in mc.wgrid]
	rt = scatter(x=mc.wgrid, y=rechazar_todo, line_color="#0098e9", name = "u(b) + β ∫v(z) dF(z)")

	opt = scatter(x=mc.wgrid, y=mc.v, line_color="#5aa800", line_width = 3, name = "v(w)")

	traces = [at, rt, opt]

	shapes = [vline(mc.w_star, line_dash="dot", line_color="#818181")]

	annotations = [attr(x=mc.w_star, y=0, yanchor="top", yref="paper", showarrow=false, text="w*")]

	layout = Layout(shapes = shapes, 
		annotations = annotations,
		title = "Value function in McCall's model",
		width = 1920*0.5, height = 1080*0.5,
		legend = attr(orientation = "h", x = 0.05),
		xaxis = attr(zeroline = false, gridcolor="#353535"),
		yaxis = attr(zeroline = false, gridcolor="#353535"),
		paper_bgcolor="#1e1e1e", plot_bgcolor="#1e1e1e",
		font_color="white", font_size = 16, 
		# font_family = "Lato",
		)

	plot(traces, layout)
end

print("✓\nConstructor mc = McCall(; β = 0.96, γ = 0, b = 1, μw = 1, σw = 0.05, wmin = 0.5, wmax = 2, Nw = 50\n")
print("Main loop vfi!(mc), ")
print("For plots: make_plots(mc)\n")
