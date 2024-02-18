include("data.jl")
include("ga.jl")
include("ip.jl")

##################  
### Parâmetros ###
##################  

# key - orden
# value - tempo de execução da ordem
ordem_tempo::Dict{String, Float64} = Dict{String, Float64}(
                                                 "OP1" => 12,
                                                 "OP2" => 10,
                                                 "OP3" => 8,
                                                 "OP4" => 4,
                                                )
ordem_ids::Vector{String} = collect(keys(ordem_tempo))

# key - máquina de enfesto
# value - tempo de setup da máquina
enfesto_tempo::Dict{String, Float64} = Dict{String, Float64}(
                                                 "E1" => 2,
                                                 "E2" => 3
                                                )
enfesto_ids::Vector{String} = collect(keys(enfesto_tempo))

#
instancia::Instancia = Instancia(
                                 ordem_tempo,
                                 ordem_ids,
                                 enfesto_tempo,
                                 enfesto_ids
                                )

#
#solucao::Solucao = IP(instancia)
solucao::Solucao = GA(instancia)

logSolution(solucao, instancia)
