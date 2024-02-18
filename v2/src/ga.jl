
SEED::Int = 1234
CONFIGURATION_FILE = "config.conf"
NUM_GENERATIONS = 100


function getSolucao(
        chromosome::Vector{Float64}, 
        instancia::Instancia
    )::Solucao

    n_ordens::Int = length(instancia.ordem_ids)

    permutation::Vector{Tuple{Float64, Int64}} = Vector{Tuple{Float64, Int64}}(
                                                                               undef, 
                                                                               n_ordens
                                                                              )
    for (index::Int, key::Float64) in enumerate(chromosome)
        permutation[index] = (key, index)
    end

    sort!(permutation)

    #
    solucao::Solucao = Solucao(
                               map(
                                   enfesto_id::String -> enfesto_id => Vector{String}(),
                                   instancia.enfesto_ids
                                  )
                              )

    enfestos_sequencia::Vector{String} = collect(
                                                 Iterators.take(
                                                                Iterators.cycle(instancia.enfesto_ids), 
                                                                length(instancia.ordem_ids)
                                                               )
                                                )

    #
    for (_, ordem_index::Int) in permutation

        ordem_id::String = instancia.ordem_ids[ordem_index]

        enfesto_id::String = popfirst!(enfestos_sequencia)

        push!(solucao[enfesto_id], ordem_id)

    end

    #
    return solucao 
end

"""
    function decode!(chromosome::Array{Float64}, instance::Instance,
                         rewrite::Bool = true)::Float64

"""
################################################################################

function decode!(
        chromosome::Vector{Float64}, 
        instancia::Instancia,
        rewrite::Bool
    )::Float64

    #
    solucao::Solucao = getSolucao(chromosome, instancia)

    #
    return getCusto(solucao, instancia)
end


function GA(instancia::Instancia)::Solucao
    brkga_data, control_params = build_brkga(
                                             instancia, 
                                             decode!, 
                                             MINIMIZE, 
                                             SEED, 
                                             length(instancia.ordem_ids),
                                             CONFIGURATION_FILE
                                            )

    initialize!(brkga_data)

    evolve!(brkga_data, NUM_GENERATIONS)

    chromosome::Vector{Float64} = get_best_chromosome(brkga_data)

#    best_cost = get_best_fitness(brkga_data)
    solucao::Solucao = getSolucao(chromosome, instancia)

    return solucao
end
