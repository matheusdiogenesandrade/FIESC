using JuMP, CPLEX

function IP(instancia::Instancia)::Solucao

    ##################  
    ### Parâmetros ###
    ##################  

    ordem_tempo::Dict{String, Float64}   = instancia.ordem_tempo
    ordem_ids::Vector{String}            = instancia.ordem_ids
    enfesto_tempo::Dict{String, Float64} = instancia.enfesto_tempo
    enfesto_ids::Vector{String}          = instancia.enfesto_ids

    ##############
    ### Modelo ###
    ##############

    model = Model(CPLEX.Optimizer)
    set_silent(model)

    # Variáveis

    @variable(model, x[o::String in ordem_ids, e::String in enfesto_ids], Bin)
    @variable(model, 0 <= m)

    # Função objetivo

    @objective(model, Min, m)

    # Restrições

    @constraint(
                model, 
                limitante_inferior_m[e::String in enfesto_ids], 
                sum(o::String -> x[o, e] * (ordem_tempo[o] + enfesto_tempo[e]), ordem_ids) <= m
               )

    @constraint(
                model, 
                atribuicao_ordem[o::String in ordem_ids], 
                sum(e::String -> x[o, e], enfesto_ids) == 1
               )

    # Executar

    optimize!(model)

    # Obter solução

    x_val = value.(x)

    solucao::Solucao = Solucao(
                               map(
                                   enfesto_id::String -> enfesto_id => Vector{String}(),
                                   instancia.enfesto_ids
                                  )
                              )

    for e::String in enfesto_ids
        for o::String in ordem_ids
            if value(x[o, e]) > .5
                push!(solucao[e], o)
            end
        end
    end

    # Imprimir status
    
#    @show termination_status(model)
#    @show primal_status(model)

    return solucao

end
