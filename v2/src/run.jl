include("data.jl")
include("ip.jl")

##################  
### Parâmetros ###
##################  

enfestos::Vector{Enfesto} = [ Enfesto("E1", 2), Enfesto("E2", 3) ]
cortes::Vector{Corte} = [ Corte("C1", 4, 5) ]
ordens::Vector{Ordem} = [ 
#                         Ordem("OP1", 3, 18, 4),
#                         Ordem("OP2", 3, 14, 4),
#                         Ordem("OP3", 4, 12, 6),
                         Ordem("OP4", 4, 6, 6),
                         Ordem("OP5", 8, 36, 12),
                         Ordem("OP6", 6, 9, 6),
#                         Ordem("OP7", 2, 9, 2),
#                         Ordem("OP8", 2, 12, 2),
#                         Ordem("OP9", 4, 12, 4),
                        ]

#
instancia::Instancia = Instancia(
                                 enfestos,
                                 cortes,
                                 ordens,
                                 10
                                )

#

IP(instancia)
