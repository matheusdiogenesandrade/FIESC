using BrkgaMpIpr

struct Instancia <: AbstractInstance
    ordem_tempo::Dict{String, Float64}
    ordem_ids::Vector{String}
    enfesto_tempo::Dict{String, Float64}
    enfesto_ids::Vector{String} 
end

const Solucao = Dict{String, Vector{String}}

function getCusto(solucao::Solucao, instancia::Instancia)::Float64

    return maximum(
               map(
                   (
                    enfesto_id, 
                    ordens_ids
                   )::Pair{String, Vector{String}} -> 
                   sum(ordem_id::String -> enfesto_tempo[enfesto_id] + instancia.ordem_tempo[ordem_id], ordens_ids), 
                   collect(solucao)
                  )
              )

end

function logSolution(solution::Solucao, instancia::Instancia)

    ordem_tempo::Dict{String, Float64}   = instancia.ordem_tempo
    ordem_ids::Vector{String}            = instancia.ordem_ids
    enfesto_tempo::Dict{String, Float64} = instancia.enfesto_tempo
    enfesto_ids::Vector{String}          = instancia.enfesto_ids

    for e::String in enfesto_ids

        tempo_consumido::Float64 = 0

        println("Enfesto $e:")

        for o::String in solucao[e]

            println("\t- Ordem $o;")

            tempo_consumido += ordem_tempo[o] + enfesto_tempo[e]

        end

        println("\tTempo consumido: $tempo_consumido.")

    end

    println("Tempo máximo total: $(getCusto(solucao, instancia))")

end
