using JuMP, GLPK, CPLEX

function IP(instancia::Instancia)::Solucao
#function IP(instancia::Instancia)::Solucao

    ##################  
    ### Parâmetros ###
    ##################  

    enfestos::Dict{String, Enfesto} = Dict{String, Enfesto}(map(enfesto::Enfesto -> enfesto.id => enfesto, instancia.enfestos))
    cortes::Dict{String, Corte}     = Dict{String, Corte}(map(corte::Corte -> corte.id => corte, instancia.cortes))
    ordens::Dict{String, Ordem}     = Dict{String, Ordem}(map(ordem::Ordem -> ordem.id => ordem, instancia.ordens))

    enfesto_ids::Vector{String}    = collect(keys(enfestos)) 
    corte_ids::Vector{String}      = collect(keys(cortes))
    ordem_ids::Vector{String}      = collect(keys(ordens))

    max_tempo_setup_enfesto::Int = maximum(enfesto_id::String -> enfestos[enfesto_id].tempo_setup, enfesto_ids)
    max_tempo_setup_corte::Int = maximum(corte_id::String -> cortes[corte_id].tempo_setup, corte_ids)
    max_tempo_transf_corte::Int = maximum(corte_id::String -> cortes[corte_id].tempo_troca, corte_ids)

    limite_tempo::Int = sum(
                            map(
                                ordem_id::String -> 
                                    max_tempo_setup_enfesto
                                    + ordens[ordem_id].tempo_enfesto 
                                    + max_tempo_transf_corte
                                    + max_tempo_setup_corte
                                    + ordens[ordem_id].tempo_corte, 
                                ordem_ids
                               )
                           )
    limite_tempo = 170
    T::Vector{Int} = collect(1:limite_tempo)

    ##############
    ### Modelo ###
    ##############

#    model = Model(GLPK.Optimizer)
    model = Model(CPLEX.Optimizer)
    #set_attribute(model, "msg_lev", GLPK.GLP_MSG_OFF)

    # Variáveis

    # Execução das ordens nos enfestos
    @variable(model, b_enfesto[o::String in ordem_ids, e::String in enfesto_ids, t::Int in T], Bin)
    @variable(model, f_enfesto[o::String in ordem_ids, e::String in enfesto_ids, t::Int in T], Bin)
    @variable(model, x_enfesto[o::String in ordem_ids, e::String in enfesto_ids, t::Int in T], Bin)

    # Corte das ordens
    @variable(model, b_corte[o::String in ordem_ids, e::String in enfesto_ids, c::String in corte_ids, t::Int in T], Bin)
    @variable(model, f_corte[o::String in ordem_ids, e::String in enfesto_ids, c::String in corte_ids, t::Int in T], Bin)
    @variable(model, x_corte[o::String in ordem_ids, e::String in enfesto_ids, c::String in corte_ids, t::Int in T], Bin)

    # Transferência de máquina de corte
    @variable(model, b_transf_corte[e::String in enfesto_ids, c::String in corte_ids, t::Int in T], Bin)
    @variable(model, f_transf_corte[e::String in enfesto_ids, c::String in corte_ids, t::Int in T], Bin)
    @variable(model, x_transf_corte[e::String in enfesto_ids, c::String in corte_ids, t::Int in T], Bin)
    @variable(model, local_corte[e::String in enfesto_ids, c::String in corte_ids, t::Int in T], Bin)

    # Inicio de operação de máquina de corte
    @variable(model, inic_corte[e::String in enfesto_ids, c::String in corte_ids, t::Int in T], Bin)

    # Quantidade de tecido 
    @variable(model, quantidade_tecido[e::String in enfesto_ids, t::Int in T], Int, upper_bound = instancia.capacidade_mesa)

    # Arcos
    @variable(model, preced[o::String in ordem_ids, o_::String in ordem_ids, e::String in enfesto_ids], Bin)

    #
    @variable(model, 0 <= m)

    # Função objetivo

    @objective(model, Min, m)

    # Restrições
    
    # Atualizar função objetivo
    @constraint(
                model, 
                funcao_objetivo_lift[
                                   o::String in ordem_ids, 
                                   e::String in enfesto_ids, 
                                   c::String in corte_ids, 
                                   t::Int in T
                                  ], 
                m >= x_corte[o, e, c, t] * t
               )
    @constraint(
                model, 
                funcao_objetivo_lift1[
                                   o::String in ordem_ids, 
                                   e::String in enfesto_ids, 
                                   t::Int in T
                                  ], 
                m >= x_enfesto[o, e, t] * t
               )

    # Preprocessamento
    @constraint(
                model, 
                preprocessamento[o::String in ordem_ids, e::String in enfesto_ids], 
                sum([
                     b_enfesto[o, e, t] 
                     for t in limite_tempo - tempo_min_total(ordens[o], enfestos[e], instancia) + 2:limite_tempo
                    ]) == 0
               )
    @constraint(
                model, 
                preprocessamento1[o::String in ordem_ids, e::String in enfesto_ids], 
                sum([
                     f_enfesto[o, e, t] 
                     for t in 1:tempo_fim_ordem_enfesto(ordens[o], enfestos[e], 0)
                    ]) == 0
               )
    @constraint(
                model, 
                preprocessamento2[o::String in ordem_ids, e::String in enfesto_ids, c::String in corte_ids], 
                sum([
                     b_corte[o, e, c, t] 
                     for t in limite_tempo - (cortes[c].tempo_setup + ordens[o].tempo_corte) + 2:limite_tempo
                    ]) == 0
               )
    @constraint(
                model, 
                preprocessamento3[o::String in ordem_ids, e::String in enfesto_ids, c::String in corte_ids], 
                sum([
                     f_corte[o, e, c, t] 
                     for t in 1:tempo_min_total(ordens[o], cortes[c], instancia) - 1
                    ]) == 0
               )
    @constraint(
                model, 
                preprocessamento4[e::String in enfesto_ids, c::String in corte_ids], 
                sum([
                     b_transf_corte[e, c, t] 
                     for t in limite_tempo - (cortes[c].tempo_troca + cortes[c].tempo_setup) + 2:limite_tempo
                    ]) == 0
               )

    # Execução das ordens nos enfestos

    @constraint(
                model, 
                servico_inicio_ordem_enfesto[o::String in ordem_ids], 
                sum([
                     b_enfesto[o, e, t] 
                     for e in enfesto_ids
                     for t in T
                    ]) == 1
               )

    @constraint(
                model, 
                servico_fim_ordem_enfesto[o::String in ordem_ids], 
                sum([
                     b_enfesto[o, e, t] 
                     for e in enfesto_ids
                     for t in T
                    ]) == 1
               )

    @constraint(
                model, 
                servico_execucao_ordem_enfesto[o::String in ordem_ids, t::Int in T], 
                sum([
                     b_enfesto[o, e, t] 
                     for e in enfesto_ids
                    ]) <= 1
               )

    @constraint(
                model, 
                servico_execucao_enfesto_tempo[e::String in enfesto_ids, t::Int in T], 
                sum([
                     x_enfesto[o, e, t] 
                     for o in ordem_ids
                    ]) <= 1
               )

    @constraint(
                model, 
                lift_ordem_enfesto[
                                   o::String in ordem_ids, 
                                   e::String in enfesto_ids, 
                                   t::Int in 1:tempo_inicio_ordem_enfesto(ordens[o], enfestos[e], limite_tempo)
                                  ], 
                b_enfesto[o, e, t] == f_enfesto[o, e, tempo_fim_ordem_enfesto(ordens[o], enfestos[e], t)]
               )

    @constraint(
                model, 
                lift_ordem_enfesto1[
                                    o::String in ordem_ids, 
                                    e::String in enfesto_ids, 
                                    t::Int in 1:tempo_inicio_ordem_enfesto(ordens[o], enfestos[e], limite_tempo), 
                                    k::Int in t:tempo_fim_ordem_enfesto(ordens[o], enfestos[e], t)
                                   ], 
                b_enfesto[o, e, t] <= x_enfesto[o, e, k]
               )

    @constraint(
                model, 
                lift_ordem_enfesto2[
                                    o::String in ordem_ids, 
                                    e::String in enfesto_ids, 
                                    t::Int in 2:limite_tempo
                                   ], 
                x_enfesto[o, e, t] <= x_enfesto[o, e, t - 1] + b_enfesto[o, e, t]
               )

    @constraint(
                model, 
                lift_ordem_enfesto3[
                                    o::String in ordem_ids, 
                                    e::String in enfesto_ids, 
                                    t::Int in 2:limite_tempo
                                   ], 
                x_enfesto[o, e, t - 1] <= 1 - b_enfesto[o, e, t]
               )

    @constraint(
                model, 
                lift_ordem_enfesto4[
                                    o::String in ordem_ids, 
                                    e::String in enfesto_ids, 
                                    t::Int in 1:limite_tempo - 1
                                   ], 
                x_enfesto[o, e, t] <= x_enfesto[o, e, t + 1] + f_enfesto[o, e, t]
               )

    @constraint(
                model, 
                lift_ordem_enfesto5[
                                    o::String in ordem_ids, 
                                    e::String in enfesto_ids, 
                                    t::Int in 1:limite_tempo - 1
                                   ], 
                x_enfesto[o, e, t + 1]  <= 1 - f_enfesto[o, e, t]
               )

    # Execução das ordens nas máquinas de corte

    @constraint(
                model, 
                servico_inicio_ordem_corte[o::String in ordem_ids], 
                sum([
                     b_corte[o, e, c, t] 
                     for c in corte_ids
                     for e in enfesto_ids
                     for t in T
                    ]) == 1
               )

    @constraint(
                model, 
                servico_fim_ordem_corte[o::String in ordem_ids], 
                sum([
                     f_corte[o, e, c, t] 
                     for c in corte_ids
                     for e in enfesto_ids
                     for t in T
                    ]) == 1
               )

    @constraint(
                model, 
                servico_inicio_ordem_tempo_corte[o::String in ordem_ids, t::Int in T], 
                sum([
                     b_corte[o, e, c, t] 
                     for c in corte_ids
                     for e in enfesto_ids
                    ]) <= 1
               )

    @constraint(
                model, 
                servico_fim_ordem_tempo_corte[o::String in ordem_ids, t::Int in T], 
                sum([
                     f_corte[o, e, c, t] 
                     for c in corte_ids
                     for e in enfesto_ids
                    ]) <= 1
               )

    @constraint(
                model, 
                servico_execucao_ordem_tempo_corte[o::String in ordem_ids, t::Int in T], 
                sum([
                     x_corte[o, e, c, t] 
                     for c in corte_ids
                     for e in enfesto_ids
                    ]) <= 1
               )

    @constraint(
                model, 
                servico_inicio_corte_tempo_corte[c::String in corte_ids, t::Int in T], 
                sum([
                     b_corte[o, e, c, t] 
                     for o in ordem_ids
                     for e in enfesto_ids
                    ]) <= 1
               )

    @constraint(
                model, 
                servico_fim_corte_tempo_corte[c::String in corte_ids, t::Int in T], 
                sum([
                     f_corte[o, e, c, t] 
                     for o in ordem_ids
                     for e in enfesto_ids
                    ]) <= 1
               )

    @constraint(
                model, 
                servico_execucao_corte_tempo_corte[c::String in corte_ids, t::Int in T], 
                sum([
                     x_corte[o, e, c, t] 
                     for o in ordem_ids
                     for e in enfesto_ids
                    ]) <= 1
               )

    @constraint(
                model, 
                lift_ordem_corte[
                                   o::String in ordem_ids, 
                                   e::String in enfesto_ids, 
                                   c::String in corte_ids, 
                                   t::Int in 1:tempo_inicio_ordem_corte(ordens[o], cortes[c], limite_tempo)
                                  ], 
                b_corte[o, e, c, t] == f_corte[o, e, c, tempo_fim_ordem_corte(ordens[o], cortes[c], t)]
               )

    @constraint(
                model, 
                lift_ordem_corte1[
                                    o::String in ordem_ids, 
                                    e::String in enfesto_ids, 
                                    c::String in corte_ids, 
                                    t::Int in 1:tempo_inicio_ordem_corte(ordens[o], cortes[c], limite_tempo), 
                                    k::Int in t:tempo_fim_ordem_corte(ordens[o], cortes[c], t)
                                   ], 
                b_corte[o, e, c, t] <= x_corte[o, e, c, k]
               )

    @constraint(
                model, 
                lift_ordem_corte2[
                                    o::String in ordem_ids, 
                                    e::String in enfesto_ids, 
                                    c::String in corte_ids, 
                                    t::Int in 2:limite_tempo
                                   ], 
                x_corte[o, e, c, t] <= x_corte[o, e, c, t - 1] + b_corte[o, e, c, t]
               )

    @constraint(
                model, 
                lift_ordem_corte3[
                                    o::String in ordem_ids, 
                                    e::String in enfesto_ids, 
                                    c::String in corte_ids, 
                                    t::Int in 2:limite_tempo
                                   ], 
                x_corte[o, e, c, t - 1] <= 1 - b_corte[o, e, c, t]
               )

    @constraint(
                model, 
                lift_ordem_corte4[
                                    o::String in ordem_ids, 
                                    e::String in enfesto_ids, 
                                    c::String in corte_ids, 
                                    t::Int in 1:limite_tempo - 1
                                   ], 
                x_corte[o, e, c, t] <= x_corte[o, e, c, t + 1] + f_corte[o, e, c, t]
               )

    @constraint(
                model, 
                lift_ordem_corte5[
                                    o::String in ordem_ids, 
                                    e::String in enfesto_ids, 
                                    c::String in corte_ids, 
                                    t::Int in 1:limite_tempo - 1
                                   ], 
                x_corte[o, e, c, t + 1] <= 1 - f_corte[o, e, c, t]
               )
   
    # Execução de transferência de máquina de corte
    @constraint(
                model, 
                max_uma_transf[
                               c::String in corte_ids, 
                               t::Int in T
                              ], 
                sum([
                     x_transf_corte[e, c, t] 
                     for e in enfesto_ids
                    ]) <= 1
               )

    @constraint(
                model, 
                max_uma_transf_corte[
                               e::String in enfesto_ids,
                               t::Int in T
                              ], 
                sum([
                     x_transf_corte[e, c, t] 
                     for c::String in corte_ids
                    ]) <= 1
               )

    @constraint(
                model, 
                lift_transf_corte[
                                   e::String in enfesto_ids, 
                                   c::String in corte_ids, 
                                   t::Int in 1:tempo_inicio_transf_corte(cortes[c], limite_tempo)
                                  ], 
                b_transf_corte[e, c, t] == f_transf_corte[e, c, tempo_fim_transf_corte(cortes[c], t)]
               )

    @constraint(
                model, 
                lift_transf_corte1[
                                    e::String in enfesto_ids, 
                                    c::String in corte_ids, 
                                    t::Int in 1:tempo_inicio_transf_corte(cortes[c], limite_tempo), 
                                    k::Int in t:tempo_fim_transf_corte(cortes[c], t)
                                   ], 
                b_transf_corte[e, c, t] <= x_transf_corte[e, c, k]
               )

    @constraint(
                model, 
                lift_transf_corte2[
                                    e::String in enfesto_ids, 
                                    c::String in corte_ids, 
                                    t::Int in 2:limite_tempo
                                   ], 
                x_transf_corte[e, c, t] <= x_transf_corte[e, c, t - 1] + b_transf_corte[e, c, t]
               )

    @constraint(
                model, 
                lift_transf_corte3[
                                    e::String in enfesto_ids, 
                                    c::String in corte_ids, 
                                    t::Int in 2:limite_tempo
                                   ], 
                x_transf_corte[e, c, t - 1] <= 1 - b_transf_corte[e, c, t]
               )

    @constraint(
                model, 
                lift_transf_corte4[
                                    e::String in enfesto_ids, 
                                    c::String in corte_ids, 
                                    t::Int in 1:limite_tempo - 1
                                   ], 
                x_transf_corte[e, c, t] <= x_transf_corte[e, c, t + 1] + f_transf_corte[e, c, t]
               )

    @constraint(
                model, 
                lift_transf_corte5[
                                    e::String in enfesto_ids, 
                                    c::String in corte_ids, 
                                    t::Int in 1:limite_tempo - 1
                                   ], 
                x_transf_corte[e, c, t + 1] <= 1 - f_transf_corte[e, c, t]
               )

    @constraint(
                model, 
                lift_transf_corte6[
                                    e::String in enfesto_ids, 
                                    o::String in ordem_ids, 
                                    c::String in corte_ids, 
                                    t::Int in 2:limite_tempo
                                   ], 
                b_corte[o, e, c, t] <= inic_corte[e, c, t] + f_transf_corte[e, c, t - 1] + local_corte[e, c, t]
               )

    @constraint(
                model, 
                lift_transf_corte8[
                                    c::String in corte_ids, 
                                    t::Int in T
                                   ], 
                sum(
                    e::String -> x_transf_corte[e, c, t] + sum(
                                     o::String -> x_corte[o, e, c, t], 
                                     ordem_ids
                                    ), 
                    enfesto_ids
                   ) <= 1
               )

    @constraint(
                model, 
                lift_transf_corte9[
                                    e::String in enfesto_ids, 
                                    c::String in corte_ids, 
                                    t::Int in 1:limite_tempo - 1
                                   ], 
                    sum(o::String -> b_corte[o, e, c, t + 1], ordem_ids) >= f_transf_corte[e, c, t]
               )
    @constraint(
                model, 
                lift_transf_corte10[
                                    c::String in corte_ids, 
                                    e::String in enfesto_ids, 
                                    e_::String in filter(e_::String -> e_ != e, enfesto_ids), 
                                    t::Int in 2:limite_tempo
                                   ], 
                local_corte[e, c, t] + local_corte[e_, c, t - 1] - 1 <= b_transf_corte[e, c, t]
               )
    @constraint(
                model, 
                lift_transf_corte11[
                                    c::String in corte_ids, 
                                    e::String in enfesto_ids, 
                                    t::Int in 1:limite_tempo
                                   ], 
                1 - b_transf_corte[e, c, t] >= inic_corte[e, c, t]
               )
    
    # Local da máquina de corte
    @constraint(
                model, 
                impor_local_corte[
                                   c::String in corte_ids, 
                                   t::Int in T
                                  ], 
                sum([
                     local_corte[e, c, t] 
                     for e in enfesto_ids
                    ]) == 1
               )

    @constraint(
                model, 
                local_corte_lift[
                                   e::String in enfesto_ids, 
                                   c::String in corte_ids, 
                                   t::Int in T
                                  ], 
                local_corte[e, c, t] >= inic_corte[e, c, t]
               )

    @constraint(
                model, 
                local_corte_lift1[
                                    e::String in enfesto_ids, 
                                    o::String in ordem_ids, 
                                    c::String in corte_ids, 
                                    t::Int in T
                                   ], 
                b_corte[o, e, c, t] <= local_corte[e, c, t] 
               )

    # Inicio de operação de máquina de corte
    @constraint(
                model, 
                primeiro_corte[c::String in corte_ids], 
                sum([
                     inic_corte[e, c, t] 
                     for e in enfesto_ids
                     for t in T
                    ]) == 1
               )

    @constraint(
                model, 
                primeiro_corte_lift[
                                    e::String in enfesto_ids,
                                    c::String in corte_ids,
                                    t::Int in 1:limite_tempo,
                                    k::Int in 1:t
                                   ], 
                1 - inic_corte[e, c, t] >= sum(e_::String -> f_transf_corte[e_, c, k], enfesto_ids)
               )

    @constraint(
                model, 
                primeiro_corte_lift1[
                                    e::String in enfesto_ids,
                                    o::String in ordem_ids,
                                    c::String in corte_ids,
                                    t::Int in 1:limite_tempo,
                                    k::Int in 1:t
                                   ], 
                1 - inic_corte[e, c, t] >= sum(e_::String -> f_transf_corte[e_, c, k], enfesto_ids)
               )

    @constraint(
                model, 
                primeiro_corte_lift2[
                                    e::String in enfesto_ids,
                                    c::String in corte_ids,
                                    t::Int in 2:limite_tempo,
                                    k::Int in 1:t - 1
                                   ], 
                1 - inic_corte[e, c, t] >= sum(map(o::String -> f_corte[o, e, c, k], ordem_ids))
               )
    @constraint(
                model, 
                primeiro_corte_lift3[
                                    e::String in enfesto_ids,
                                    o::String in ordem_ids,
                                    c::String in corte_ids,
                                    t::Int in 2:limite_tempo,
                                    k::Int in 1:t - 1
                                   ], 
                1 - inic_corte[e, c, t] >= sum(map(e_::String -> f_corte[o, e_, c, k], enfesto_ids))
               )
    #=
    @constraint(
                model, 
                primeiro_corte_lift4[
                                    e::String in enfesto_ids,
                                    c::String in corte_ids,
                                    t::Int in 2:limite_tempo
                                   ], 
                inic_corte[e, c, t] >= sum(map(o::String -> b_corte[o, e, c, t], ordem_ids))
               )
    =#

    # Precedencia
    @constraint(
                model, 
                impor_precedencia_enfesto[
                                    e::String in enfesto_ids,
                                    o::String in ordem_ids,
                                    o_::String in ordem_ids,
                                    t::Int in T,
                                    k::Int in t + 1:limite_tempo,
                                   ], 
                preced[o, o_, e] >= f_enfesto[o, e, t] + f_enfesto[o_, e, k] - 1
               )

    @constraint(
                model, 
                impor_precedencia_corte[
                                    e::String in enfesto_ids,
                                    c::String in corte_ids,
                                    o::String in ordem_ids,
                                    o_::String in ordem_ids,
                                    t::Int in T,
                                    k::Int in t + 1:limite_tempo,
                                   ], 
                preced[o, o_, e] >= f_corte[o, e, c, t] + f_corte[o_, e, c, k] - 1
               )

    @constraint(
                model, 
                nao_reverso_precedencia[
                                    e::String in enfesto_ids,
                                    o::String in ordem_ids,
                                    o_::String in ordem_ids
                                   ], 
                preced[o, o_, e] + preced[o_, o, e] <= 1
               )

    # Precedencia de enfesto e corte
    @constraint(
                model, 
                enfesto_antes_de_corte[
                                    e::String in enfesto_ids,
                                    o::String in ordem_ids,
                                    c::String in corte_ids,
                                    t::Int in 1:limite_tempo - 1
                                   ], 
                f_enfesto[o, e, t] <= sum(map(k::Int -> b_corte[o, e, c, k], t + 1:limite_tempo))
               )

    # Quantidade de tecido 
    @constraint(
                model, 
                atualizar_qntd_tecido[
                                      e::String in enfesto_ids,
                                      t::Int in T 
                                     ], 
                quantidade_tecido[e, t] == sum([ordens[o].comprimento * (f_enfesto[o, e, k] - sum( c::String -> f_corte[o, e, c, k], corte_ids)) for o in ordem_ids for k in 1:t - 1 ])
               )

    #=
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
               =#

    # Executar

    optimize!(model)

    # Obter solução

    # Execução ordens
    b_enfesto_val = value.(b_enfesto)
    f_enfesto_val = value.(f_enfesto)
    x_enfesto_val = value.(x_enfesto)

    # Corte das ordens
    b_corte_val = value.(b_corte)
    f_corte_val = value.(f_corte)
    x_corte_val = value.(x_corte)

    # Transferência de máquina de corte
    b_transf_corte_val = value.(b_transf_corte)
    f_transf_corte_val = value.(f_transf_corte)
    x_transf_corte_val = value.(x_transf_corte)
    local_corte_val = value.(local_corte)

    # Inicio de operação de máquina de corte
    inic_corte_val = value.(inic_corte)

    # Quatidade de tecido
    quantidade_tecido_val = value.(quantidade_tecido)

    # 
    inner_solucao::Dict{String, Vector{String}} = Dict{String, Vector{String}}()
    for enfesto_id::String in enfesto_ids
        inner_solucao[enfesto_id] = ["" for i::Int in T]
        inner_solucao["#Tecido " * enfesto_id] = ["" for i::Int in T]
    end
    for enfesto_id::String in enfesto_ids 
        for corte_id::String in corte_ids
            inner_solucao[enfesto_id * "/" * corte_id] = ["" for i::Int in T]
        end
    end

    # Transferência de máquina de corte
    for t::Int in T
        for e::String in enfesto_ids
            inner_solucao["#Tecido " * e][t] = string(quantidade_tecido_val[e, t])

            for c::String in corte_ids

                if b_transf_corte_val[e, c, t] > .5 && f_transf_corte_val[e, c, t] > .5
                    inner_solucao[e * "/" * c][t] = "+-M"
                elseif b_transf_corte_val[e, c, t] > .5 
                    inner_solucao[e * "/" * c][t] = "+M" 
                elseif f_transf_corte_val[e, c, t] > .5
                    inner_solucao[e * "/" * c][t] = "-M"
                elseif x_transf_corte_val[e, c, t] > .5
                    inner_solucao[e * "/" * c][t] = "M"
                end

            end

            for o::String in ordem_ids

                if b_enfesto_val[o, e, t] > .5 && f_enfesto_val[o, e, t] > .5
                    inner_solucao[e][t] = "+-" * o
                elseif b_enfesto_val[o, e, t] > .5
                    inner_solucao[e][t] = "+" * o
                elseif f_enfesto_val[o, e, t] > .5
                    inner_solucao[e][t] = "-" * o
                elseif x_enfesto_val[o, e, t] > .5
                    inner_solucao[e][t] = o
                end

                for c::String in corte_ids

                    if b_corte_val[o, e, c, t] > .5 && f_corte_val[o, e, c, t] > .5
                        inner_solucao[e * "/" * c][t] = "+-" * o
                    elseif b_corte_val[o, e, c, t] > .5 
                        inner_solucao[e * "/" * c][t] = "+" * o
                    elseif f_corte_val[o, e, c, t] > .5
                        inner_solucao[e * "/" * c][t] = "-" * o
                    elseif x_corte_val[o, e, c, t] > .5
                        inner_solucao[e * "/" * c][t] = o
                    end

                end

            end

        end
    end

    #
    solucao::Solucao = DataFrame(inner_solucao)

    #
    to_csv(solucao, "solucao.csv")

    return solucao

end

