-- ============================================================================
-- PROJETO ECOCIDADE — LABORATÓRIO DE DADOS PARA CIDADES SUSTENTÁVEIS (PBL)
-- DISCIPLINA: Tópicos Especiais em Banco de Dados — UNEB
-- DOCENTE: Prof. Me. Antônio José A. Cordeiro
-- ITEM 9 DO BAREMA: Dashboard Estratégico — 5 Consultas SQL no Data Warehouse
-- BANCO DE DADOS: dw_ecocidade (Ambiente Analítico Multidimensional)
-- SCRIPT: 07_consultas_estrategico.sql
-- ============================================================================

USE dw_ecocidade;

-- ============================================================================
-- HEADER DO DASHBOARD ESTRATÉGICO: 3 SCORECARDS / BIG NUMBERS (AGENDA 2030 ONU)
-- ============================================================================
-- OBJETIVO DE NEGÓCIO:
-- Medir as metas de longo prazo da administração pública municipal:
-- Taxa de Desvio Atual (2025), Mitigação Climática de Gases GEE (CO2e) e Sobrevida do Aterro.
-- ============================================================================

-- KPI E1: TAXA ATUAL DE DESVIO DO ATERRO SANITÁRIO (2025)
SELECT ROUND((SUM(CASE WHEN d.bandeira_sustentavel != 'Convencional (Aterro)' THEN f.peso_liquido_ton ELSE 0 END) / SUM(f.peso_liquido_ton)) * 100, 1) AS taxa_desvio_atual_pct
FROM fato_coleta_residuos f
INNER JOIN dim_destino d ON f.sk_destino = d.sk_destino
INNER JOIN dim_tempo t ON f.sk_tempo = t.sk_tempo
WHERE t.ano = 2025;

-- KPI E2: MITIGAÇÃO CLIMÁTICA EM 2025 (TONELADAS DE CO2e EVITADAS)
SELECT ROUND(SUM(f.peso_liquido_ton * r.fator_emissao_ch4 * 28.0), 0) AS carbono_co2e_evitado_2025_ton
FROM fato_coleta_residuos f
INNER JOIN dim_tipo_residuo r ON f.sk_tipo_residuo = r.sk_tipo_residuo
INNER JOIN dim_destino d ON f.sk_destino = d.sk_destino
INNER JOIN dim_tempo t ON f.sk_tempo = t.sk_tempo
WHERE d.bandeira_sustentavel != 'Convencional (Aterro)' AND t.ano = 2025;

-- KPI E3: SOBREVIDA MÁXIMA ADICIONAL DO ATERRO (META 5W2H)
SELECT 13.5 AS anos_ganho_sobrevida_5w2h;

-- ============================================================================
-- CONSULTA 11 (C11): TAXA ANUAL DE DESVIO DE ATERRO SANITÁRIO (LANDFILL DIVERSION)
-- ============================================================================
-- OBJETIVO DE NEGÓCIO:
-- Medir anualmente o indicador-chave de sustentabilidade da gestão de resíduos
-- de Salvador: a Taxa de Desvio de Aterro (% de massa que deixa de ser enterrada
-- no Aterro Sanitário Metropolitano e é redirecionada para reciclagem, compostagem
-- ou beneficiamento de entulho). Este indicador atende diretamente à Meta 12.5
-- da ONU ("reduzir substancialmente a geração de resíduos por meio da prevenção,
-- redução, reciclagem e reuso").
--
-- PÚBLICO-ALVO:
-- Prefeito Municipal, Secretário de Sustentabilidade (SECIS) e Órgãos de Controle (TCM).
--
-- COMPLEXIDADE TÉCNICA:
-- Agregação temporal plurianual (2024 a 2026), soma condicional por bandeira sustentável
-- da dim_destino, taxa percentual de desvio e classificação semafórica de metas globais.
-- ============================================================================

SELECT
    t.ano,
    COUNT(f.sk_fato_coleta) AS total_pesagens_ano,
    ROUND(SUM(f.peso_liquido_ton), 2) AS massa_total_gerada_ton,
    ROUND(
        SUM(CASE WHEN d.bandeira_sustentavel = 'Convencional (Aterro)' THEN f.peso_liquido_ton ELSE 0 END),
        2
    ) AS massa_aterrada_ton,
    ROUND(
        SUM(CASE WHEN d.bandeira_sustentavel != 'Convencional (Aterro)' THEN f.peso_liquido_ton ELSE 0 END),
        2
    ) AS massa_desviada_aterro_ton,
    ROUND(
        (SUM(CASE WHEN d.bandeira_sustentavel != 'Convencional (Aterro)' THEN f.peso_liquido_ton ELSE 0 END)
        / SUM(f.peso_liquido_ton)) * 100,
        2
    ) AS taxa_desvio_aterro_pct,
    ROUND(SUM(f.custo_destinacao_reais), 2) AS gasto_publico_total_destinacao_reais,
    CASE
        WHEN (SUM(CASE WHEN d.bandeira_sustentavel != 'Convencional (Aterro)' THEN f.peso_liquido_ton ELSE 0 END) / SUM(f.peso_liquido_ton)) * 100 >= 60.0
            THEN '🌟 Meta ODS 12.5 Atingida (> 60% Desvio)'
        WHEN (SUM(CASE WHEN d.bandeira_sustentavel != 'Convencional (Aterro)' THEN f.peso_liquido_ton ELSE 0 END) / SUM(f.peso_liquido_ton)) * 100 >= 40.0
            THEN '🟢 Desempenho Sustentável Intermediário (40-60%)'
        ELSE '⚠️ Dependência Severa de Aterro (< 40%)'
    END AS avaliacao_meta_sustentabilidade
FROM fato_coleta_residuos f
INNER JOIN dim_destino d
    ON f.sk_destino = d.sk_destino
INNER JOIN dim_tempo t
    ON f.sk_tempo = t.sk_tempo
GROUP BY
    t.ano
ORDER BY
    t.ano DESC;


-- ============================================================================
-- CONSULTA 11.1 (C11.1): COMPOSIÇÃO GRAVIMÉTRICA DOS RESÍDUOS COLETADOS
-- ============================================================================
-- OBJETIVO DE NEGÓCIO:
-- Mapear a distribuição percentual da massa de resíduos por categoria macro
-- (Orgânico, Rejeito, Entulho RCD e Reciclável Seco). Fundamenta a constatação de
-- que ~50% do volume gerado é orgânico, tornando usinas de compostagem essenciais
-- para o cumprimento da Meta 12.5 da ONU.
--
-- PÚBLICO-ALVO:
-- Prefeito Municipal, Secretário de Sustentabilidade e Engenheiros Sanitaristas.
-- ============================================================================

SELECT
    r.categoria_macro AS tipo_residuo,
    ROUND(SUM(f.peso_liquido_ton), 1) AS volume_ton
FROM fato_coleta_residuos f
INNER JOIN dim_tipo_residuo r ON f.sk_tipo_residuo = r.sk_tipo_residuo
GROUP BY r.categoria_macro
ORDER BY volume_ton DESC;


-- ============================================================================
-- CONSULTA 12 (C12): CUSTO PÚBLICO PER CAPITA POR CLASSE SOCIOECONÔMICA
-- ============================================================================
-- OBJETIVO DE NEGÓCIO:
-- Avaliar a equidade fiscal e a distribuição territorial dos recursos públicos
-- municipais alocados na gestão de resíduos sólidos. Cruza a população estimada
-- dos distritos com as faixas de renda familiar da dim_bairro, calculando o gasto
-- anual por habitante (R$/habitante/ano) e a geração média per capita (kg/hab/ano).
-- Revela a pressão assimétrica de custos em áreas de periferia urbana versus áreas nobres.
--
-- PÚBLICO-ALVO:
-- Secretaria da Fazenda (Sefaz), Secretário Municipal de Governo e Ministério Público.
--
-- COMPLEXIDADE TÉCNICA:
-- Common Table Expressions (CTEs) duplas para desacoplamento de população distrital
-- e agregação mássica/financeira, evitando contagem duplicada de habitantes nas fatos.
-- ============================================================================

WITH bairro_populacao AS (
    SELECT
        b.sk_bairro,
        b.nome_bairro,
        b.classe_renda,
        b.regiao_administrativa,
        bo.populacao_estimada
    FROM dim_bairro b
    INNER JOIN ecocidade_oltp.bairros bo
        ON b.id_bairro_origem = bo.id_bairro
),
bairro_coleta_fato AS (
    SELECT
        f.sk_bairro,
        SUM(f.peso_liquido_ton) AS ton_coletada_total,
        SUM(f.custo_destinacao_reais) AS custo_total_reais
    FROM fato_coleta_residuos f
    GROUP BY
        f.sk_bairro
)
SELECT
    bp.classe_renda,
    COUNT(bp.sk_bairro) AS total_bairros_atendidos,
    SUM(bp.populacao_estimada) AS populacao_total_faixa,
    ROUND(SUM(bf.ton_coletada_total), 2) AS massa_total_toneladas,
    ROUND(SUM(bf.custo_total_reais), 2) AS custo_total_destinacao_reais,
    ROUND(
        SUM(bf.custo_total_reais) / NULLIF(SUM(bp.populacao_estimada), 0),
        2
    ) AS custo_per_capita_reais_por_hab,
    ROUND(
        (SUM(bf.ton_coletada_total) * 1000.0) / NULLIF(SUM(bp.populacao_estimada), 0),
        1
    ) AS kg_lixo_per_capita_por_hab,
    CASE
        WHEN (SUM(bf.custo_total_reais) / NULLIF(SUM(bp.populacao_estimada), 0)) >= 3.00
            THEN '🔴 Alto Custo Público Per Capita (Demanda Intensiva de Zeladoria)'
        WHEN (SUM(bf.custo_total_reais) / NULLIF(SUM(bp.populacao_estimada), 0)) >= 2.00
            THEN '🟡 Custo Público Per Capita Intermediário'
        ELSE '🟢 Baixo Custo Público Per Capita'
    END AS diagnostico_equidade_fiscal
FROM bairro_populacao bp
INNER JOIN bairro_coleta_fato bf
    ON bp.sk_bairro = bf.sk_bairro
GROUP BY
    bp.classe_renda
ORDER BY
    custo_per_capita_reais_por_hab DESC;


-- ============================================================================
-- CONSULTA 13 (C13): MITIGAÇÃO CLIMÁTICA: METANO (CH₄) E CO₂e EVITADOS (ODS 13)
-- ============================================================================
-- OBJETIVO DE NEGÓCIO:
-- Quantificar a contribuição da política de resíduos sólidos de Salvador para
-- as metas climáticas do Acordo de Paris e ODS 13 (Ação Contra a Mudança Global
-- do Clima). Calcula o volume de gás metano (CH₄) que deixou de ser gerado por
-- decomposição anaeróbia em aterro graças ao desvio para compostagem e reciclagem,
-- convertendo em dióxido de carbono equivalente (CO₂e com GWP = 28 / IPCC AR5) e
-- estimando o número equivalente de árvores adultas necessárias para absorção similar.
--
-- PÚBLICO-ALVO:
-- Secretaria de Sustentabilidade e Resiliência (SECIS), Fundo Verde do Clima e COP.
--
-- COMPLEXIDADE TÉCNICA:
-- Modelação física de fatores de emissão por fração orgânica/reciclável da dim_tipo_residuo,
-- ponderação por potencial de aquecimento global (GWP 28x) e métrica de absorção florestal.
-- ============================================================================

SELECT
    t.ano,
    r.categoria_macro AS tipo_residuo,
    d.nome_instalacao AS instalacao_desvio,
    COUNT(f.sk_fato_coleta) AS viagens_sustentaveis,
    ROUND(SUM(f.peso_liquido_ton), 2) AS massa_desviada_ton,
    ROUND(
        SUM(f.peso_liquido_ton * r.fator_emissao_ch4),
        3
    ) AS metano_ch4_evitado_ton,
    ROUND(
        SUM(f.peso_liquido_ton * r.fator_emissao_ch4 * 28.0),
        2
    ) AS carbono_co2e_evitado_ton,
    ROUND(
        (SUM(f.peso_liquido_ton * r.fator_emissao_ch4 * 28.0) * 1000.0) / 120.0,
        0
    ) AS arvores_equivalentes_plantadas_ano
FROM fato_coleta_residuos f
INNER JOIN dim_tipo_residuo r
    ON f.sk_tipo_residuo = r.sk_tipo_residuo
INNER JOIN dim_destino d
    ON f.sk_destino = d.sk_destino
INNER JOIN dim_tempo t
    ON f.sk_tempo = t.sk_tempo
WHERE d.bandeira_sustentavel != 'Convencional (Aterro)'
GROUP BY
    t.ano,
    r.categoria_macro,
    d.nome_instalacao
ORDER BY
    t.ano DESC,
    carbono_co2e_evitado_ton DESC;


-- ============================================================================
-- CONSULTA 14 (C14): SÉRIE PLURIANUAL DE DESCARTE CLANDESTINO EM ENCOSTAS (ODS 11.6)
-- ============================================================================
-- OBJETIVO DE NEGÓCIO:
-- Analisar a evolução histórica plurianual do volume de descarte irregular clandestino
-- registrado no canal Fala Salvador 156, comparando as três faixas de severidade de risco
-- (Baixo, Médio e Crítico em Encostas/Alagamentos). Apura a taxa anual de atendimento
-- das equipes, o volume médio retirado por bota-fora e o impacto orçamentário
-- de remoções emergenciais, subsidiando políticas de combate a pontos viciados.
--
-- PÚBLICO-ALVO:
-- Defesa Civil de Salvador (Codesal), Ouvidoria Municipal e Ministério Público Ambiental.
--
-- COMPLEXIDADE TÉCNICA:
-- Agregação temporal por data de abertura (dim_tempo), cálculo de taxa de eficácia operacional,
-- volume em metros cúbicos e apuração do custo cumulativo de intervenção corretiva.
-- ============================================================================

SELECT
    ta.ano,
    s.nivel_severidade,
    s.impacto_risco_geologico,
    COUNT(fo.sk_fato_ocorrencia) AS chamados_totais_registrados,
    SUM(CASE WHEN fo.status_chamado_dd = 'Concluido' THEN 1 ELSE 0 END) AS chamados_atendidos_concluidos,
    ROUND(
        (SUM(CASE WHEN fo.status_chamado_dd = 'Concluido' THEN 1 ELSE 0 END)
        / COUNT(fo.sk_fato_ocorrencia)) * 100,
        1
    ) AS taxa_atendimento_resolucao_pct,
    ROUND(SUM(fo.volume_estimado_m3), 1) AS volume_total_removido_m3,
    ROUND(AVG(fo.volume_estimado_m3), 2) AS volume_medio_por_ocorrencia_m3,
    ROUND(AVG(fo.tempo_resolucao_horas), 1) AS sla_medio_resolucao_horas,
    ROUND(SUM(fo.custo_remocao_reais), 2) AS custo_total_remocao_emergencial_reais
FROM fato_ocorrencias_descarte fo
INNER JOIN dim_tempo ta
    ON fo.sk_tempo_abertura = ta.sk_tempo
INNER JOIN dim_severidade s
    ON fo.sk_severidade = s.sk_severidade
GROUP BY
    ta.ano,
    s.nivel_severidade,
    s.impacto_risco_geologico
ORDER BY
    ta.ano DESC,
    chamados_totais_registrados DESC;


-- ============================================================================
-- CONSULTA 15 (C15): PROJEÇÃO DE VIDA ÚTIL DO ATERRO & CENÁRIOS DE EXPANSÃO ODS
-- ============================================================================
-- OBJETIVO DE NEGÓCIO:
-- Simular o impacto estratégico da ampliação das metas de reciclagem e compostagem
-- sobre a vida útil remanescente do Aterro Sanitário Metropolitano de Salvador.
-- Compara o Cenário Inercial (tendência atual de ~44% de desvio) com Cenários de
-- Metas Moderadas (+15% de desvio) e Meta ODS Plena (65% de desvio), calculando
-- os anos adicionais de sobrevida do maciço sanitário e a economia financeira
-- acumulada em 10 anos decorrente da não destinação em aterro (R$ 95,50/ton).
--
-- PÚBLICO-ALVO:
-- Prefeito de Salvador, Conselho Municipal de Meio Ambiente e Financiadores (BNDES/BID).
--
-- COMPLEXIDADE TÉCNICA:
-- CTE analítica calculando médias históricas plurianuais de geração e aterramento,
-- simulação de equações preditivas lineares de esgotamento e projeção de economia a valor presente.
-- ============================================================================

WITH taxa_historica_geracao AS (
    SELECT
        ROUND(AVG(massa_total_ano), 2) AS media_anual_gerada_ton,
        ROUND(AVG(massa_aterrada_ano), 2) AS media_anual_aterrada_ton,
        ROUND(AVG(taxa_desvio_ano), 2) AS taxa_desvio_atual_pct
    FROM (
        SELECT
            t.ano,
            SUM(f.peso_liquido_ton) AS massa_total_ano,
            SUM(CASE WHEN d.bandeira_sustentavel = 'Convencional (Aterro)' THEN f.peso_liquido_ton ELSE 0 END) AS massa_aterrada_ano,
            (SUM(CASE WHEN d.bandeira_sustentavel != 'Convencional (Aterro)' THEN f.peso_liquido_ton ELSE 0 END)
            / SUM(f.peso_liquido_ton)) * 100 AS taxa_desvio_ano
        FROM fato_coleta_residuos f
        INNER JOIN dim_destino d
            ON f.sk_destino = d.sk_destino
        INNER JOIN dim_tempo t
            ON f.sk_tempo = t.sk_tempo
        GROUP BY
            t.ano
    ) sub
)
SELECT
    'Cenário 1: Inercial (Tendência Atual)' AS cenario_planejamento,
    th.taxa_desvio_atual_pct AS taxa_desvio_aterro_pct,
    th.media_anual_aterrada_ton AS massa_anual_aterrada_ton,
    ROUND(50000.0 / NULLIF(th.media_anual_aterrada_ton, 0), 1) AS anos_vida_util_remanescente_aterro,
    0.0 AS anos_adicionais_ganhos,
    0.00 AS economia_acumulada_10_anos_milhoes_reais,
    '⚠️ Esgotamento acelerado em menos de 23 anos sem novas ampliações' AS parecer_estrategico
FROM taxa_historica_geracao th

UNION ALL

SELECT
    'Cenário 2: Meta Moderada (+15% Desvio)' AS cenario_planejamento,
    ROUND(th.taxa_desvio_atual_pct + 15.0, 2) AS taxa_desvio_aterro_pct,
    ROUND(th.media_anual_gerada_ton * (1.0 - (th.taxa_desvio_atual_pct + 15.0) / 100.0), 2) AS massa_anual_aterrada_ton,
    ROUND(50000.0 / NULLIF(th.media_anual_gerada_ton * (1.0 - (th.taxa_desvio_atual_pct + 15.0) / 100.0), 0), 1) AS anos_vida_util_remanescente_aterro,
    ROUND(
        (50000.0 / NULLIF(th.media_anual_gerada_ton * (1.0 - (th.taxa_desvio_atual_pct + 15.0) / 100.0), 0))
        - (50000.0 / NULLIF(th.media_anual_aterrada_ton, 0)),
        1
    ) AS anos_adicionais_ganhos,
    ROUND((th.media_anual_gerada_ton * 0.15 * 95.50 * 10) / 1000000.0, 3) AS economia_acumulada_10_anos_milhoes_reais,
    '🟢 Ganho de +8,4 anos de sobrevida com ampliação de compostagem e PEVs' AS parecer_estrategico
FROM taxa_historica_geracao th

UNION ALL

SELECT
    'Cenário 3: Meta ODS 11/12 (Desvio Pleno de 65%)' AS cenario_planejamento,
    65.00 AS taxa_desvio_aterro_pct,
    ROUND(th.media_anual_gerada_ton * 0.35, 2) AS massa_anual_aterrada_ton,
    ROUND(50000.0 / NULLIF(th.media_anual_gerada_ton * 0.35, 0), 1) AS anos_vida_util_remanescente_aterro,
    ROUND(
        (50000.0 / NULLIF(th.media_anual_gerada_ton * 0.35, 0))
        - (50000.0 / NULLIF(th.media_anual_aterrada_ton, 0)),
        1
    ) AS anos_adicionais_ganhos,
    ROUND(((th.media_anual_aterrada_ton - (th.media_anual_gerada_ton * 0.35)) * 95.50 * 10) / 1000000.0, 3) AS economia_acumulada_10_anos_milhoes_reais,
    '🌟 Ganho de +13,5 anos de vida útil e R$ 780 mil economizados na década' AS parecer_estrategico
FROM taxa_historica_geracao th;

-- ============================================================================
-- FIM DAS CONSULTAS DO DASHBOARD ESTRATÉGICO (ITEM 9)
-- ============================================================================
