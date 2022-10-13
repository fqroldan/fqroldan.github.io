using ColorSchemes

include("itpcake.jl")

function armar_mat(Nvec = [200, 500, 1_000, 2_000, 10_000], r = 1e-4)

    cm = [CakeEating(r=r, Nk = N) for _ in 1:2, N in Nvec]
    
    # cm = Matrix{CakeEating}(undef, 2, length(Nvec))
    # for (jj, N) in enumerate(Nvec)
    #     cm[:, jj] .= [CakeEating(r = r, Nk = N) for _ in 1:2]
    # end

    for jN in axes(cm, 2)
        vfi!(cm[1, jN], verbose = false)
        vfi_itp!(cm[2, jN], verbose = false)
        print("\n")
    end
    return cm
end

function plots_cm(cm::Matrix{CakeEating})

    K = size(cm, 2)

    plot([
        [scatter(x = ce.kgrid, y = ce.gc ./ ce.kgrid, name = "Nk = $(length(ce.kgrid)), vfi", line_dash = "solid", marker_color = get(ColorSchemes.lajolla, jj/K), line_width = 2.5) for (jj, ce) in enumerate(cm[1, :])]
        [scatter(x = ce.kgrid, y = ce.gc ./ ce.kgrid, name = "Nk = $(length(ce.kgrid)), itp", line_dash = "dashdot", marker_color = get(ColorSchemes.lajolla, jj/K), line_width = 2.5) for (jj, ce) in enumerate(cm[2, :])]
    ], 
    Layout(
        font_size = 16, font_family = "Lato",
    ))
end