include("data.jl")
include("ip.jl")

##################  
### Parâmetros ###
##################  

enfestos::Vector{Enfesto} = [ 
                             Enfesto("E1", 2), 
#                             Enfesto("E2", 3) 
                            ]
cortes::Vector{Corte} = [ Corte("C1", 4, 5) ]
ordens::Vector{Ordem} = [ 
Ordem("OP1", 3, 18,  4),
Ordem("OP2", 3, 14,  4),
Ordem("OP3", 4, 12,  6),
Ordem("OP4", 4, 6 ,  6),
                        ]
#
instancia::Instancia = Instancia(
                                 enfestos,
                                 cortes,
                                 ordens,
                                 100
                                )

#
IP(instancia)
