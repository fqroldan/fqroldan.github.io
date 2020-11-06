print("Arellano, C. (2008): ``Default Risk and Income Fluctuations in Emerging Economies,'' American Economic Review, 98, 690--712.\n")
print("Loading codes…")

using QuantEcon, Optim, Interpolations, Printf, LinearAlgebra, PlotlyJS, ColorSchemes#, NLopt

abstract type Deuda
end

mutable struct NoDefault <: Deuda
	β::Float64
	γ::Float64
	r::Float64

	bgrid::Vector{Float64}
	ygrid::Vector{Float64}

	Py::Matrix{Float64}

	v::Dict{Symbol, Matrix{Float64}}
end
function NoDefault(;
	β = 0.953,
	γ = 2,
	r = 0.017,

	ρ = 0.945,
	η = 0.025,

	Nb = 60,
	Ny = 21,

	bmax = 0.75)

	ychain = tauchen(Ny, ρ, η, 0, 3)

	Py = ychain.p
	ygrid = exp.(ychain.state_values)

	bgrid = range(0, bmax, length=Nb)

	v = Dict(key => zeros(Nb, Ny) for key in [:v, :c, :b])

	return NoDefault(β, γ, r, bgrid, ygrid, Py, v)
end
mutable struct Def <: Deuda
	β::Float64
	γ::Float64
	r::Float64
	θ::Float64
	κ::Float64

	bgrid::Vector{Float64}
	ygrid::Vector{Float64}

	Py::Matrix{Float64}

	v::Dict{Symbol, Matrix{Float64}}
end

function Def(;
	β = 0.953,
	γ = 2,
	r = 0.017,
	θ = 0.282,
	κ = 0.04,

	ρ = 0.945,
	η = 0.025,

	Nb = 200,
	Ny = 21,

	bmax = 0.75)
	ychain = tauchen(Ny, ρ, η, 0, 3)

	Py = ychain.p
	ygrid = exp.(ychain.state_values)

	bgrid = range(0, bmax, length=Nb)

	v = Dict(key => zeros(Nb, Ny) for key in [:v, :R, :D, :prob, :cR, :cD, :b, :q, :qb])

	return Def(β, γ, r, θ, κ, bgrid, ygrid, Py, v)
end

function u(c, dd::Deuda)
	if dd.γ == 1
		return log(c)
	else
		return c^(1-dd.γ) / (1-dd.γ)
	end
end

function expect_v(bpv, py, itp_v, dd::Deuda)
	Ev = 0.0
	for (jyp, ypv) in enumerate(dd.ygrid)
		prob = py[jyp]
		Ev += prob * itp_v[:v](bpv, ypv)
	end
	return Ev
end

budget_constraint(bpv, qv, bv, yv) = yv - bv + qv*bpv
debtprice(bpv, py, itp_v, dd::Deuda) = 1/(1+dd.r)

function eval_value(bpv, bv, yv, py, itp_v, dd::Deuda)
	qv = debtprice(bpv, py, itp_v, dd)

	c = budget_constraint(bpv, qv, bv, yv)
	vp = expect_v(bpv, py, itp_v, dd)

	return u(c, dd) + dd.β * vp
end

function optim_value(bv, yv, py, itp_v, dd::Deuda; optim::Bool=true)
	if optim
		return optim_value1(bv, yv, py, itp_v, dd)
	else
		return optim_value2(bv, yv, py, itp_v, dd)
	end
end

function optim_value1(bv, yv, py, itp_v, dd::Deuda)
	obj_f(bpv) = -eval_value(bpv, bv, yv, py, itp_v, dd)

	maxb = min(maximum(dd.bgrid), bv + 0.2)
	minb = minimum(dd.bgrid)

	res = Optim.optimize(obj_f, minb, maxb, GoldenSection())
	b_opt = res.minimizer
	v_opt = -res.minimum

	qv = debtprice(b_opt, py, itp_v, dd)
	c_opt  = budget_constraint(b_opt, qv, bv, yv) 

	return b_opt, c_opt, v_opt
end

function optim_value2(bv, yv, py, itp_v, dd::Deuda)
	v_opt = -Inf
	b_opt = 0.0
	c_opt = 0.0
	for (jbp, bpv) in enumerate(dd.bgrid)
		v = eval_value(bpv, bv, yv, py, itp_v, dd)

		if v > v_opt
			v_opt = v
			qv = debtprice(bpv, py, itp_v, dd)
			c_opt = budget_constraint(bpv, qv, bv, yv)
			b_opt = bpv
		end
	end
	return b_opt, c_opt, v_opt
end

function vf_iter!(new_v, dd::Deuda)
	itp_v = Dict(key => interpolate((dd.bgrid, dd.ygrid), dd.v[key], Gridded(Linear())) for key in keys(dd.v))
	for (jb, bv) in enumerate(dd.bgrid), (jy, yv) in enumerate(dd.ygrid)
		py = dd.Py[jy, :]

		b_opt, c_opt, v_opt = optim_value(bv, yv, py, itp_v, dd, optim=true)

		new_v[:b][jb, jy] = b_opt
		new_v[:c][jb, jy] = c_opt
		new_v[:v][jb, jy] = v_opt
	end
end

function debtprice(bpv, py, itp_v, dd::Def)
	defprob = 0.0
	for (jyp, ypv) in enumerate(dd.ygrid)
		prob = py[jyp]
		defprob += prob * itp_v[:prob](bpv, ypv)
	end
	return (1-defprob) / (1+dd.r)
end

defcost(yv, dd::Deuda) = min(yv, 0.969 * 1.0)
# defcost(yv, dd::Deuda) = yv * 0.9

function value_default(yv, py, itp_v, dd::Def)
	c = defcost(yv, dd)

	Ev = 0.0
	for (jyp, ypv) in enumerate(dd.ygrid)
		prob = py[jyp]
		Ev += prob * ( dd.θ * itp_v[:v](0.0, ypv) + (1-dd.θ) * itp_v[:D](0.0, ypv) )
	end
	v = u(c, dd) + dd.β * Ev
	return c, v
end

function update_defprob!(v, dd::Def)
	for (jy, yv) in enumerate(dd.ygrid), (jb, bv) in enumerate(dd.bgrid)
		vD = v[:D][jb, jy]
		vR = v[:R][jb, jy]

		if dd.κ >= 0.001
			prob = exp(vD/dd.κ) / (exp(vD/dd.κ) + exp(vR/dd.κ))
			if isnan(prob)
				prob = (vD > vR)
			end
		else
			prob = (vD > vR)
		end
		v[:v][jb, jy] = prob * vD + (1-prob) * vR
		v[:prob][jb, jy] = prob
	end
end

function vf_iter!(new_v, dd::Def)
	itp_v = Dict(key => interpolate((dd.bgrid, dd.ygrid), dd.v[key], Gridded(Linear())) for key in keys(dd.v))
	for (jy, yv) in enumerate(dd.ygrid)
		py = dd.Py[jy, :]

		for (jb, bv) in enumerate(dd.bgrid)
			b_opt, c_opt, v_opt = optim_value(bv, yv, py, itp_v, dd, optim=true)

			new_v[:b][jb, jy] = b_opt
			new_v[:cR][jb, jy] = c_opt
			new_v[:R][jb, jy] = v_opt
			new_v[:q][jb, jy] = debtprice(bv, py, itp_v, dd)
		end

		c_opt, v_opt = value_default(yv, py, itp_v, dd)
		new_v[:cD][:, jy] .= c_opt
		new_v[:D][:, jy]  .= v_opt
	end
	update_defprob!(new_v, dd)
	new_v[:qb] = new_v[:q] .* new_v[:b]
end

function update_v!(new_v, dd::Deuda; upd_η = 1)
	for key in keys(new_v)
		dd.v[key] = dd.v[key] + upd_η * (new_v[key] - dd.v[key])
	end
end

function vfi!(dd::Deuda; tol=1e-4, maxiter = 2000)
	iter, dist = 0, 1+tol
	new_v = Dict(key => similar(val) for (key, val) in dd.v)

	while iter < maxiter && dist > tol
		iter += 1
		
		vf_iter!(new_v, dd)

		dist = maximum([ norm(new_v[key] - dd.v[key]) / (1+norm(dd.v[key])) for key in keys(dd.v) ])

		norm_v = 1+maximum([norm(dd.v[key]) for key in keys(dd.v)])

		print("Iteration $iter: dist = $(@sprintf("%0.3g", dist)) at ‖v‖ = $(@sprintf("%0.3g", norm_v))\n")

		update_v!(new_v, dd)
	end
end

new_b(dd::Deuda, bv, yv, def, itp_v) = itp_v[:b][bv, yv]

function new_b(dd::Def, bv, yv, def, itp_v)
	if def
		return 0.0
	else
		return itp_v[:b][bv, yv]
	end
end

new_defprob(bpv, ypv, itp_v, def, dd::Deuda) = 0.0
function new_defprob(bpv, ypv, itp_v, def, dd::Def)
	if def
		return 1-dd.θ
	else
		return itp_v[:prob](bpv, ypv)
	end
end

function iter_simul!(path, tt, b0, jy, def::Bool, dd::Deuda, itp_v)
	
	y0 = dd.ygrid[jy]
	def ? y0 = defcost(y0, dd) : nothing

	path[:b][tt] = b0
	path[:y][tt] = y0
	path[:def][tt] = def

	bpv = new_b(dd, b0, y0, def, itp_v)
	
	jyp = findfirst(cumsum(dd.Py[jy,:]) .>= rand())
	ypv = dd.ygrid[jyp]

	defprob = new_defprob(bpv, ypv, itp_v, def, dd)
	path[:prob][tt] = defprob

	def_pv = (rand() < defprob)

	return def_pv, bpv, jyp
end

function simul(dd::Deuda; T = 10000)
	path = Dict(key => Vector{Float64}(undef, T) for key in [:b, :y, :prob, :def])

	itp_v = Dict(key => interpolate((dd.bgrid, dd.ygrid), dd.v[key], Gridded(Linear())) for key in keys(dd.v))

	jy = 1
	b0 = mean(dd.bgrid)
	def = false
	for tt in 1:T
		def, b0, jy = iter_simul!(path, tt, b0, jy, def, dd, itp_v)
	end

	return path
end

make_panels(dd::Def; sym1=:v, sym2=:cR) = make_panels_back(dd, sym1, sym2)
make_panels(dd::NoDefault; sym1=:v, sym2=:c) = make_panels_back(dd, sym1, sym2)
function make_panels_back(dd::Deuda, sym1, sym2)

	val = [scatter(x=-dd.bgrid, y=dd.v[sym1][:, jy], xaxis="x1", yaxis="y1", name = "y=$(@sprintf("%0.3g",yv))", marker_color=get(ColorSchemes.lajolla, 0.75*(jy-1)/(length(dd.ygrid)-1)), legendgroup=jy) for (jy, yv) in enumerate(dd.ygrid)  if jy % 3 == 0]

	pol = [scatter(x=-dd.bgrid, y=dd.v[sym2][:, jy], xaxis="x2", yaxis="y2", name = "y=$(@sprintf("%0.3g",yv))", showlegend=false, marker_color=get(ColorSchemes.lajolla, 0.75*(jy-1)/(length(dd.ygrid)-1)), legendgroup=jy) for (jy, yv) in enumerate(dd.ygrid)  if jy % 3 == 0]

	data = [val; pol]

	annotations = [
		attr(text=sym1, x=-mean(dd.bgrid), xref="x1", xanchor="center", y=1, yref="paper", showarrow=false, yanchor="bottom", font_size=18)
		attr(text=sym2, x=-mean(dd.bgrid), xref="x2", xanchor="center", y=1, yref="paper", showarrow=false, yanchor="bottom", font_size=18)
	]

	typeof(dd) == Def ? title="Deuda con riesgo" : title = "Deuda libre de riesgo"

	layout = Layout(title=title,
		annotations=annotations,
		width = 1920*0.5, height = 1080*0.5,
		legend = attr(orientation="h",x=0.5,xref="paper",xanchor="center"),
		xaxis1 = attr(domain=[0,0.45],zeroline=false, gridcolor="#353535"),
		xaxis2 = attr(domain=[0.55,1],zeroline=false, gridcolor="#353535"),
		yaxis1 = attr(zeroline=false, gridcolor="#353535", anchor="x1"),
		yaxis2 = attr(zeroline=false, gridcolor="#353535", anchor="x2"),
		paper_bgcolor="#1e1e1e", plot_bgcolor="#1e1e1e",
		font_color="white", font_size = 16, font_family = "Lato",
		)

	plot(data, layout)
end

function make_plots(dd::Def)

	repagar = [scatter(x=-dd.bgrid, y=dd.v[:R][:,jy], name="y=$(@sprintf("%0.3g",yv))", marker_color=get(ColorSchemes.lajolla, 0.75*(jy-1)/(length(dd.ygrid)-1)), legendgroup=jy) for (jy, yv) in enumerate(dd.ygrid)  if jy % 3 == 0]
	defaultear = [scatter(x=-dd.bgrid, y=dd.v[:D][:, jy], marker_color=get(ColorSchemes.lajolla, 0.75*(jy-1)/(length(dd.ygrid)-1)), legendgroup=jy, showlegend=false, line_dash="dash") for (jy, yv) in enumerate(dd.ygrid)  if jy % 3 == 0]
	vf = [scatter(x=-dd.bgrid, y=dd.v[:v][:, jy], marker_color=get(ColorSchemes.lajolla, 0.75*(jy-1)/(length(dd.ygrid)-1)), legendgroup=jy, showlegend=false, line_dash="dot") for (jy, yv) in enumerate(dd.ygrid)  if jy % 3 == 0]

	data = [repagar; defaultear; vf]

layout = Layout(title="<i>V(b,y)</i> en el modelo de Arellano",
		width = 1920*0.5, height = 1080*0.5,
		legend = attr(orientation = "h", x = 0.05),
		xaxis = attr(zeroline = false, gridcolor="#353535"),
		yaxis = attr(zeroline = false, gridcolor="#353535"),
		paper_bgcolor="#1e1e1e", plot_bgcolor="#1e1e1e",
		font_color="white", font_size = 16, font_family = "Lato",
		)

	plot(data, layout)
end

function make_plots(dd::Def, sym::Symbol)

	if sym==:q
		multiplier = (-dd.bgrid)
	elseif sym == :b || sym == :qb
		multiplier = -1
	else
		multiplier = 1
	end

	data = [scatter(x=-dd.bgrid, y=dd.v[sym][:, jy].*multiplier, name="y=$(@sprintf("%0.3g",yv))", marker_color=get(ColorSchemes.lajolla, 0.75*(jy-1)/(length(dd.ygrid)-1))) for (jy, yv) in enumerate(dd.ygrid) if jy % 3 == 0]

	annotations = []
	ytitle = ""
	if sym == :q
		push!(data, scatter(x=-dd.bgrid, y=-dd.bgrid.*(1/(1+dd.r)), showlegend=false, name="Risk-free", line_dash="dashdot", marker_color=get(ColorSchemes.davos, 0.5)))
		push!(annotations, attr(text = "pendiente = 1 / (1+r)", x=-0.35 + 0.005, y=-0.35/(1+dd.r) - 0.005, ay = 25, ax = 40, xanchor = "left", arrowcolor=get(ColorSchemes.davos, 0.5), font_color="#c4c4c4")
			)
		ytitle = "<i>q(b',y) b'"
	end

	layout = Layout(title="Curva de Laffer de la deuda", annotations=annotations,
		width = 1920*0.5, height = 1080*0.5,
		legend = attr(orientation="h",x=0.5,xref="paper",xanchor="center"),
		xaxis = attr(zeroline = false, gridcolor="#353535"),
		yaxis = attr(zeroline = false, gridcolor="#353535", title=ytitle),
		paper_bgcolor="#1e1e1e", plot_bgcolor="#1e1e1e",
		font_color="white", font_size = 16, font_family = "Lato",
		)

	plot(data, layout)
end

print(" ✓\n")

print("Constructor dd = NoDefault(; β = 0.953, γ = 2, r = 0.017, ρ = 0.945, η = 0.025, Nb = 60, Ny = 21, bmax = 0.75)\n")
print("Constructor dd = Def(; β = 0.953, γ = 2, r = 0.017, θ = 0.282, κ = 0.18, ρ = 0.945, η = 0.025, Nb = 200, Ny = 21, bmax = 0.75)\n")
print("Main loop vfi!(dd::Deuda)\n")
print("For plots: make_panels(dd::Deuda; sym1, sym2)\n")
print("For Laffer plot: make_plot(dd::Def, sym=:q)\n")
