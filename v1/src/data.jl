using BrkgaMpIpr
using Pandas

struct Enfesto
    id::String
    tempo_setup::Int
end

struct Corte
    id::String
    tempo_setup::Int
    tempo_troca::Int
end

struct Ordem
    id::String
    comprimento::Int
    tempo_enfesto::Int
    tempo_corte::Int
end

struct Instancia <: AbstractInstance
    enfestos::Vector{Enfesto}
    cortes::Vector{Corte}
    ordens::Vector{Ordem}
    capacidade_mesa::Int
end

tempo_fim_ordem_enfesto(o::Ordem, e::Enfesto, t::Int)::Int = t + e.tempo_setup + o.tempo_enfesto - 1
tempo_inicio_ordem_enfesto(o::Ordem, e::Enfesto, t::Int)::Int = t - (e.tempo_setup + o.tempo_enfesto) + 1

tempo_fim_ordem_corte(o::Ordem, c::Corte, t::Int)::Int = t + c.tempo_setup + o.tempo_enfesto - 1
tempo_inicio_ordem_corte(o::Ordem, c::Corte, t::Int)::Int = t - (c.tempo_setup + o.tempo_enfesto) + 1

tempo_fim_transf_corte(c::Corte, t::Int)::Int = t + c.tempo_troca - 1
tempo_inicio_transf_corte(c::Corte, t::Int)::Int = t - c.tempo_troca + 1

tempo_min_total(o::Ordem, e::Enfesto, instancia::Instancia) = e.tempo_setup + o.tempo_enfesto + minimum(c::Corte -> c.tempo_setup, instancia.cortes) + o.tempo_corte

tempo_min_total(o::Ordem, c::Corte, instancia::Instancia) = minimum(e::Enfesto -> e.tempo_setup, instancia.enfestos) + o.tempo_enfesto + c.tempo_setup + o.tempo_corte

const Solucao = DataFrame

#=
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
=#
