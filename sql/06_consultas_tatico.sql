-- ============================================================================
-- PROJETO ECOCIDADE — LABORATÓRIO DE DADOS PARA CIDADES SUSTENTÁVEIS (PBL)
-- DISCIPLINA: Tópicos Especiais em Banco de Dados — UNEB
-- DOCENTE: Prof. Me. Antônio José A. Cordeiro
-- ITEM 8 DO BAREMA: Dashboard Tático — 5 Consultas SQL no Data Warehouse
-- BANCO DE DADOS: dw_ecocidade (Ambiente Analítico Multidimensional)
-- SCRIPT: 06_consultas_tatico.sql
-- ============================================================================

USE dw_ecocidade;

-- ============================================================================
-- CONSULTA 6 (C6): CUSTO MENSAL DE DESTINAÇÃO FINAL POR PREFEITURA-BAIRRO
-- ============================================================================
-- OBJETIVO DE NEGÓCIO:
-- Apresentar o balanço financeiro e volumétrico do custo público de manejo de
-- resíduos sólidos urbanos, consolidado por Região Administrativa (Prefeitura-Bairro)
-- e macrocategoria de resíduo (Orgânico, Reciclável Seco, Entulho RCD, Rejeito).
-- Subsidia a Secretaria da Fazenda (Sefaz) e a Limpurb na apuração do gasto
-- público distrital e na identificação de distritos com maior sangria orçamentária
-- em taxas de soterramento no Aterro Sanitário Metropolitano.
--
-- PÚBLICO-ALVO:
-- Coordenador Financeiro da Limpurb, Gerentes das Prefeituras-Bairro e Analistas de Orçamento.
--
-- COMPLEXIDADE TÉCNICA:
-- Junção estrela entre fato_coleta_residuos, dim_bairro, dim_tipo_residuo e dim_tempo,
-- agregações anuais/mensais (SUM/COUNT), custo médio por tonelada e ordenação decrescente.
-- ============================================================================

SELECT
    b.regiao_administrativa AS prefeitura_bairro,
    r.categoria_macro AS categoria_residuo,
    t.ano,
    COUNT(f.sk_fato_coleta) AS total_viagens_descarregadas,
    ROUND(SUM(f.peso_liquido_ton), 2) AS volume_total_toneladas,
    ROUND(SUM(f.custo_destinacao_reais), 2) AS custo_total_destinacao_reais,
    ROUND(
        SUM(f.custo_destinacao_reais) / NULLIF(SUM(f.peso_liquido_ton), 0),
        2
    ) AS custo_medio_por_tonelada_reais
FROM fato_coleta_residuos f
INNER JOIN dim_bairro b
    ON f.sk_bairro = b.sk_bairro
INNER JOIN dim_tipo_residuo r
    ON f.sk_tipo_residuo = r.sk_tipo_residuo
INNER JOIN dim_tempo t
    ON f.sk_tempo = t.sk_tempo
GROUP BY
    b.regiao_administrativa,
    r.categoria_macro,
    t.ano
ORDER BY
    t.ano DESC,
    custo_total_destinacao_reais DESC;


-- ============================================================================
-- CONSULTA 7 (C7): EFICIÊNCIA ENERGÉTICA DA FROTA & INTENSIDADE DE CARBONO (CO₂)
-- ============================================================================
-- OBJETIVO DE NEGÓCIO:
-- Avaliar o desempenho logístico e a pegada de carbono da frota de coleta por
-- modelo de veículo e concessionária operadora. Calcula a tonelagem transportada
-- por quilômetro rodado (kg de resíduo / km) e a intensidade de emissões diretas
-- de Gases de Efeito Estufa (kg de CO₂ emitidos por tonelada de lixo recolhida),
-- identificando modelos de alta ecoeficiência para renovação contratual da frota.
--
-- PÚBLICO-ALVO:
-- Gestor de Sustentabilidade Urbana (ODS 11 e 13), Fiscais de Contratos de Concessão.
--
-- COMPLEXIDADE TÉCNICA:
-- Agregação na fato_coleta_residuos com dim_veiculo, cálculo de métricas de densidade
-- logística (kg/km), conversão de emissões estimadas (g para ton) e razão de intensidade.
-- ============================================================================

SELECT
    v.empresa_operadora,
    v.tipo_veiculo,
    v.modelo AS modelo_veiculo,
    COUNT(f.sk_fato_coleta) AS total_viagens_realizadas,
    ROUND(SUM(f.distancia_km), 1) AS distancia_acumulada_km,
    ROUND(SUM(f.peso_liquido_ton), 2) AS carga_total_transportada_ton,
    ROUND(
        (SUM(f.peso_liquido_ton) * 1000.0) / NULLIF(SUM(f.distancia_km), 0),
        2
    ) AS produtividade_kg_lixo_por_km,
    ROUND(SUM(f.emissoes_estimadas_co2_kg) / 1000.0, 3) AS emissoes_co2_toneladas,
    ROUND(
        SUM(f.emissoes_estimadas_co2_kg) / NULLIF(SUM(f.peso_liquido_ton), 0),
        2
    ) AS intensidade_emissao_kg_co2_por_ton,
    CASE
        WHEN (SUM(f.peso_liquido_ton) * 1000.0) / NULLIF(SUM(f.distancia_km), 0) >= 280.0
            THEN '🟢 Ecoeficiência Alta (>= 280 kg/km)'
        WHEN (SUM(f.peso_liquido_ton) * 1000.0) / NULLIF(SUM(f.distancia_km), 0) >= 200.0
            THEN '🟡 Ecoeficiência Moderada (200-280 kg/km)'
        ELSE '🔴 Rota Especializada / Baixa Densidade (< 200 kg/km)'
    END AS classificacao_ecoeficiencia
FROM fato_coleta_residuos f
INNER JOIN dim_veiculo v
    ON f.sk_veiculo = v.sk_veiculo
GROUP BY
    v.empresa_operadora,
    v.tipo_veiculo,
    v.modelo
ORDER BY
    carga_total_transportada_ton DESC;


-- ============================================================================
-- CONSULTA 8 (C8): DESEMPENHO DE SLA DO 156 CRUZADO COM CLUSTERS K-MEANS
-- ============================================================================
-- OBJETIVO DE NEGÓCIO:
-- Medir o cumprimento das metas contratuais de SLA de resolução de chamados da
-- Central Fala Salvador 156 consolidado por Prefeitura-Bairro. A consulta segmenta
-- os distritos conforme os clusters descobertos no Item 6 (Cluster Crítico de Encostas,
-- Regular Popiloso e Potencial Seletivo), demonstrando a correlação empírica entre
-- áreas de alta vulnerabilidade topográfica e morosidade no atendimento público.
--
-- PÚBLICO-ALVO:
-- Ouvidoria Geral do Município, Secretário de Governo e Prefeitos-Bairro.
--
-- COMPLEXIDADE TÉCNICA:
-- Junção entre fato_ocorrencias_descarte, dim_bairro e dim_severidade, cálculo da taxa
-- percentual de conclusão, SLA médio em horas/dias, taxa de incidência em encostas
-- e classificação paramétrica alinhada ao modelo K-Means.
-- ============================================================================

SELECT
    b.regiao_administrativa AS prefeitura_bairro,
    COUNT(fo.sk_fato_ocorrencia) AS total_chamados_156,
    SUM(CASE WHEN fo.status_chamado_dd = 'Concluido' THEN 1 ELSE 0 END) AS chamados_concluidos,
    ROUND(
        (SUM(CASE WHEN fo.status_chamado_dd = 'Concluido' THEN 1 ELSE 0 END) / COUNT(fo.sk_fato_ocorrencia)) * 100,
        1
    ) AS taxa_conclusao_pct,
    ROUND(AVG(fo.tempo_resolucao_horas), 1) AS sla_medio_horas,
    ROUND(AVG(fo.tempo_resolucao_horas) / 24.0, 1) AS sla_medio_dias,
    ROUND(
        (SUM(CASE WHEN s.impacto_risco_geologico = 'Sim' THEN 1 ELSE 0 END) / COUNT(fo.sk_fato_ocorrencia)) * 100,
        1
    ) AS taxa_ocorrencias_encosta_pct,
    CASE
        WHEN b.regiao_administrativa IN ('Liberdade/Sao Caetano', 'Suburbio Ferroviario')
            THEN '🔴 Cluster 1: Crítico (Encostas / Prioridade Máxima)'
        WHEN b.regiao_administrativa = 'Barra/Pituba'
            THEN '🟢 Cluster 3: Potencial Seletivo (Bairros Verdes)'
        ELSE '🔵 Cluster 2: Densidade Regular / Popilosa'
    END AS perfil_territorial_kmeans
FROM fato_ocorrencias_descarte fo
INNER JOIN dim_bairro b
    ON fo.sk_bairro = b.sk_bairro
INNER JOIN dim_severidade s
    ON fo.sk_severidade = s.sk_severidade
GROUP BY
    b.regiao_administrativa
ORDER BY
    sla_medio_horas DESC;


-- ============================================================================
-- CONSULTA 9 (C9): DIRECIONAMENTO A COOPERATIVAS & ECONOMIA DE CUSTO EVITADO
-- ============================================================================
-- OBJETIVO DE NEGÓCIO:
-- Monitorar o volume de resíduos recicláveis secos encaminhados às Cooperativas
-- de Catadores conveniadas (Cooperativa Camamu e Cooperativa Canore Central).
-- Calcula o valor de repasse financeiro realizado pela prefeitura (R$ 35,00/ton),
-- compara com a tarifa que seria gasta caso o material fosse aterrado no Aterro
-- Metropolitano (R$ 95,50/ton) e quantifica a Economia Líquida de Custo Evitado
-- proporcionada aos cofres públicos pela economia circular.
--
-- PÚBLICO-ALVO:
-- Coordenadoria de Cooperativas e Economia Solidária, Diretoria de Limpeza Urbana.
--
-- COMPLEXIDADE TÉCNICA:
-- Filtro por destinação sustentável (Centros de Triagem de Cooperativas), agregações
-- temporais por ano/mês, modelagem de custo evitado e margem líquida municipal.
-- ============================================================================

SELECT
    d.nome_instalacao AS cooperativa_parceira,
    d.bandeira_sustentavel,
    t.ano,
    COUNT(f.sk_fato_coleta) AS total_cargas_entregues,
    ROUND(SUM(f.peso_liquido_ton), 2) AS total_reciclavel_ton,
    ROUND(SUM(f.custo_destinacao_reais), 2) AS repasse_cooperativa_reais,
    ROUND(SUM(f.peso_liquido_ton) * 95.50, 2) AS custo_equivalente_aterro_reais,
    ROUND(
        (SUM(f.peso_liquido_ton) * 95.50) - SUM(f.custo_destinacao_reais),
        2
    ) AS economia_liquida_custo_evitado_reais,
    ROUND(
        (((SUM(f.peso_liquido_ton) * 95.50) - SUM(f.custo_destinacao_reais))
        / (SUM(f.peso_liquido_ton) * 95.50)) * 100,
        1
    ) AS percentual_economia_pct
FROM fato_coleta_residuos f
INNER JOIN dim_destino d
    ON f.sk_destino = d.sk_destino
INNER JOIN dim_tempo t
    ON f.sk_tempo = t.sk_tempo
WHERE d.tipo_instalacao = 'Centro de Triagem Cooperativa'
GROUP BY
    d.nome_instalacao,
    d.bandeira_sustentavel,
    t.ano
ORDER BY
    t.ano DESC,
    total_reciclavel_ton DESC;


-- ============================================================================
-- CONSULTA 10 (C10): AUDITORIA TÁTICA DE CONCESSIONÁRIAS DE COLETA URBANA
-- ============================================================================
-- OBJETIVO DE NEGÓCIO:
-- Auditar o desempenho operacional e financeiro consolidado de todas as concessionárias
-- terceirizadas e da autarquia pública de limpeza urbana (Limpurb Municipal,
-- Consórcio Salvador Limpa, Bahia Ambiental, Coocreve e Canore). Fornece métricas
-- comparativas de rotas cobertas, tonelagem transportada, quilômetros rodados,
-- tempo médio de descarregamento na balança e custo médio por tonelada, fornecendo
-- evidências para renovação, repactuação ou aplicação de penalidades contratuais.
--
-- PÚBLICO-ALVO:
-- Comissão Permanente de Licitação e Contratos, Diretor-Presidente da Limpurb.
--
-- COMPLEXIDADE TÉCNICA:
-- Contagem de rotas distintas (COUNT DISTINCT), média ponderada de carga útil,
-- indicadores de agilidade em balança e apuração de custo médio unitário.
-- ============================================================================

SELECT
    v.empresa_operadora,
    COUNT(DISTINCT f.codigo_rota_dd) AS rotas_distintas_cobertas,
    COUNT(f.sk_fato_coleta) AS viagens_totais_executadas,
    ROUND(SUM(f.peso_liquido_ton), 2) AS volume_total_transportado_ton,
    ROUND(AVG(f.peso_liquido_ton), 2) AS media_ton_por_viagem,
    ROUND(SUM(f.distancia_km), 1) AS distancia_acumulada_km,
    ROUND(AVG(f.tempo_descarregamento_minutos), 1) AS tempo_medio_descarregamento_min,
    ROUND(SUM(f.custo_destinacao_reais), 2) AS custo_total_destinacao_reais,
    ROUND(
        SUM(f.custo_destinacao_reais) / NULLIF(SUM(f.peso_liquido_ton), 0),
        2
    ) AS custo_medio_por_tonelada_reais,
    CASE
        WHEN v.empresa_operadora LIKE '%Coleta Seletiva%'
            THEN '♻️ Operador Social de Coleta Seletiva (Tarifa Reduzida)'
        WHEN AVG(f.tempo_descarregamento_minutos) <= 28.5 AND AVG(f.peso_liquido_ton) >= 8.5
            THEN '🟢 Concessionária de Alto Desempenho Operacional'
        ELSE '🟡 Concessionária com Operação Fracionada / Caçambas'
    END AS perfil_auditoria_concessao
FROM fato_coleta_residuos f
INNER JOIN dim_veiculo v
    ON f.sk_veiculo = v.sk_veiculo
GROUP BY
    v.empresa_operadora
ORDER BY
    volume_total_transportado_ton DESC;

-- ============================================================================
-- FIM DAS CONSULTAS DO DASHBOARD TÁTICO (ITEM 8)
-- ============================================================================
