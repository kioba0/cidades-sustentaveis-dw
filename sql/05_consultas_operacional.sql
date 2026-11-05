-- ============================================================================
-- PROJETO ECOCIDADE — LABORATÓRIO DE DADOS PARA CIDADES SUSTENTÁVEIS (PBL)
-- DISCIPLINA: Tópicos Especiais em Banco de Dados — UNEB
-- DOCENTE: Prof. Me. Antônio José A. Cordeiro
-- ITEM 7 DO BAREMA: Dashboard Operacional — 5 Consultas SQL de Chão de Fábrica
-- BANCO DE DADOS: ecocidade_oltp (Ambiente Transacional em Tempo Real)
-- SCRIPT: 05_consultas_operacional.sql
-- ============================================================================

USE ecocidade_oltp;

-- ============================================================================
-- CONSULTA 1 (C1): CONTROLE DE BALANÇA & DETECÇÃO DE FILAS DE DESCARREGAMENTO
-- ============================================================================
-- OBJETIVO DE NEGÓCIO:
-- Monitorar em tempo real as pesagens rodoviárias nas centrais de destinação
-- (Aterro Metropolitano, Usinas de Compostagem, Centros de Triagem de Cooperativas
-- e Ecopontos Centrais). Identificar veículos cujo tempo de descarregamento exceda
-- 25 minutos, provocando filas na balança de entrada, atraso de rotas e retenção
-- improdutiva de frotas pesadas.
--
-- PÚBLICO-ALVO:
-- Fiscal de Balança, Encarregado da Central de Destinação e Despachante da Limpurb.
--
-- COMPLEXIDADE TÉCNICA:
-- Junção quíntupla (pesagens_coleta, veiculos_frota, rotas_coleta, bairros e destinos_finais),
-- cálculo dinâmico de tonelagem líquida e classificação condicional de gargalos (CASE WHEN).
-- ============================================================================

SELECT
    p.id_pesagem AS protocolo_pesagem,
    p.data_hora_pesagem,
    v.placa AS placa_veiculo,
    v.modelo AS modelo_veiculo,
    v.tipo_veiculo,
    v.empresa_operadora,
    r.codigo_rota,
    r.turno AS turno_rota,
    bo.nome_bairro AS bairro_origem,
    d.nome_instalacao AS central_destino,
    p.tipo_residuo,
    ROUND(p.peso_liquido_kg / 1000.0, 2) AS peso_liquido_ton,
    p.tempo_descarregamento_minutos,
    CASE
        WHEN p.tempo_descarregamento_minutos > 35 THEN '🚨 Gargalo Crítico (> 35 min)'
        WHEN p.tempo_descarregamento_minutos > 25 THEN '⚠️ Atenção / Fila (25-35 min)'
        ELSE '🟢 Fluxo Normal (<= 25 min)'
    END AS status_operacional_balanca
FROM pesagens_coleta p
INNER JOIN veiculos_frota v
    ON p.id_veiculo = v.id_veiculo
INNER JOIN rotas_coleta r
    ON p.id_rota = r.id_rota
INNER JOIN bairros bo
    ON r.id_bairro_origem = bo.id_bairro
INNER JOIN destinos_finais d
    ON p.id_destino = d.id_destino
ORDER BY p.data_hora_pesagem DESC
LIMIT 25;


-- ============================================================================
-- CONSULTA 2 (C2): MONITORAMENTO DE LOTAÇÃO DE ECOPONTOS E CAÇAMBAS COMUNITÁRIAS
-- ============================================================================
-- OBJETIVO DE NEGÓCIO:
-- Monitorar o nível de ocupação dos Pontos de Coleta municipais ativos (Ecopontos,
-- PEVs de Recicláveis e Lixeiras Subterrâneas) correlacionando-os com o volume
-- acumulado de descartes irregulares reportados no entorno via canal Fala Salvador 156.
-- Subsidiar a emissão de Ordens de Serviço (OS) imediatas para envio de poliguindastes
-- antes do transbordamento de resíduos para vias públicas e canais de drenagem.
--
-- PÚBLICO-ALVO:
-- Supervisor de Ecopontos, Coordenador de Logística Reversa e Fiscais de Postura.
--
-- COMPLEXIDADE TÉCNICA:
-- LEFT JOIN entre pontos_coleta e chamados_descarte_irregular pendentes, agregação
-- com agregação condicional de volume (COALESCE/SUM), taxa de ocupação percentual
-- e priorização semafórica de despacho.
-- ============================================================================

SELECT
    pc.id_ponto,
    pc.nome_identificador AS local_ponto_coleta,
    pc.tipo_ponto,
    b.nome_bairro,
    b.regiao_administrativa AS prefeitura_bairro,
    pc.capacidade_m3,
    COUNT(cdi.id_chamado) AS chamados_156_pendentes_entorno,
    ROUND(COALESCE(SUM(cdi.volume_estimado_m3), 0.0), 2) AS volume_reclamado_m3,
    ROUND(
        (COALESCE(SUM(cdi.volume_estimado_m3), 0.0) / NULLIF(pc.capacidade_m3, 0)) * 100,
        1
    ) AS taxa_pressao_capacidade_pct,
    CASE
        WHEN COALESCE(SUM(cdi.volume_estimado_m3), 0.0) >= pc.capacidade_m3
            THEN '🔴 Despacho Imediato (Capacidade Esgotada)'
        WHEN COALESCE(SUM(cdi.volume_estimado_m3), 0.0) >= (pc.capacidade_m3 * 0.70)
            THEN '🟡 Alerta Preventivo (> 70% Ocupação)'
        ELSE '🟢 Nível Estável'
    END AS status_urgencia_coleta
FROM pontos_coleta pc
INNER JOIN bairros b
    ON pc.id_bairro = b.id_bairro
LEFT JOIN chamados_descarte_irregular cdi
    ON (cdi.id_ponto_coleta = pc.id_ponto OR (cdi.id_ponto_coleta IS NULL AND cdi.id_bairro = pc.id_bairro))
    AND cdi.status IN ('Aberto', 'Em Andamento')
WHERE pc.status_operacional = 'Ativo'
GROUP BY
    pc.id_ponto,
    pc.nome_identificador,
    pc.tipo_ponto,
    b.nome_bairro,
    b.regiao_administrativa,
    pc.capacidade_m3
ORDER BY
    taxa_pressao_capacidade_pct DESC,
    chamados_156_pendentes_entorno DESC;


-- ============================================================================
-- CONSULTA 3 (C3): FILA DE DESPACHO 156: OCORRÊNCIAS EM ENCOSTAS SEM EQUIPE
-- ============================================================================
-- OBJETIVO DE NEGÓCIO:
-- Listar chamados de descarte irregular abertos no Fala Salvador 156 classificados
-- formalmente com nível de severidade 'Critico / Risco Encosta ou Alagamento'
-- que permanecem sem atendimento de equipe ou veículo despachado. A consulta
-- calcula o SLA decorrido em horas e dias corridos, ordenando os chamados por
-- antiguidade para articulação imediata entre a Limpurb e a Defesa Civil (Codesal).
--
-- PÚBLICO-ALVO:
-- Central de Despacho Operacional 156, Gestores da Codesal e Coordenadores de Zeladoria.
--
-- COMPLEXIDADE TÉCNICA:
-- Funções temporais (TIMESTAMPDIFF em horas), lógica de SLA estourado (> 48h / > 72h),
-- filtragem por enum de severidade e cruzamento territorial com as Prefeituras-Bairro.
-- ============================================================================

SELECT
    c.protocolo_cidadao,
    b.nome_bairro,
    b.regiao_administrativa AS prefeitura_bairro,
    c.severidade_risco,
    c.status AS status_chamado,
    c.data_abertura,
    TIMESTAMPDIFF(HOUR, c.data_abertura, COALESCE(c.data_atendimento, NOW())) AS sla_decorrido_horas,
    ROUND(TIMESTAMPDIFF(HOUR, c.data_abertura, COALESCE(c.data_atendimento, NOW())) / 24.0, 1) AS dias_espera,
    c.volume_estimado_m3,
    CASE
        WHEN TIMESTAMPDIFF(HOUR, c.data_abertura, COALESCE(c.data_atendimento, NOW())) > 72
            THEN '⛔ CRÍTICO: Violação Grave de SLA (> 72h em Encosta)'
        WHEN TIMESTAMPDIFF(HOUR, c.data_abertura, COALESCE(c.data_atendimento, NOW())) > 48
            THEN '⚠️ ALERTA: Prazo Limite Atingido (48h-72h)'
        ELSE '⏱️ Em Tempo Hábil (< 48h)'
    END AS classificacao_atendimento_sla,
    c.descricao_ocorrencia
FROM chamados_descarte_irregular c
INNER JOIN bairros b
    ON c.id_bairro = b.id_bairro
WHERE c.severidade_risco = 'Critico / Risco Encosta ou Alagamento'
  AND (c.status IN ('Aberto', 'Em Andamento') OR c.id_veiculo_atendimento IS NULL)
ORDER BY
    sla_decorrido_horas DESC,
    c.volume_estimado_m3 DESC
LIMIT 30;


-- ============================================================================
-- CONSULTA 4 (C4): DISPONIBILIDADE DA FROTA & DIAGNÓSTICO DE CARGA ÚTIL
-- ============================================================================
-- OBJETIVO DE NEGÓCIO:
-- Avaliar em tempo de escala operacional a disponibilidade dos caminhões e veículos
-- utilitários da frota pública e terceirizada. Cruza as viagens concluídas no período,
-- calcula a tonelagem média transportada por viagem e compara com a capacidade nominal
-- do veículo para identificar ociosidade, subutilização de caçambas ou necessidade
-- de remanejamento para turnos noturnos.
--
-- PÚBLICO-ALVO:
-- Gerente de Manutenção de Frota, Fiscais de Contratos de Concessão e Despachantes.
--
-- COMPLEXIDADE TÉCNICA:
-- Agregação de pesagens com contagem de viagens (COUNT), totalização de carga (SUM),
-- média (AVG), cálculo percentual de fator de carga útil e diagnóstico analítico (CASE WHEN).
-- ============================================================================

SELECT
    v.id_veiculo,
    v.placa,
    v.modelo,
    v.tipo_veiculo,
    v.capacidade_carga_ton,
    v.empresa_operadora,
    v.status AS status_mecanico,
    COUNT(p.id_pesagem) AS total_viagens_realizadas,
    ROUND(COALESCE(SUM(p.peso_liquido_kg) / 1000.0, 0.0), 2) AS total_ton_transportadas,
    ROUND(COALESCE(AVG(p.peso_liquido_kg) / 1000.0, 0.0), 2) AS media_ton_por_viagem,
    ROUND(
        (COALESCE(AVG(p.peso_liquido_kg) / 1000.0, 0.0) / NULLIF(v.capacidade_carga_ton, 0)) * 100,
        1
    ) AS taxa_aproveitamento_capacidade_pct,
    CASE
        WHEN v.status != 'Operacional'
            THEN '🔧 Indisponível (Oficina / Manutenção)'
        WHEN COUNT(p.id_pesagem) = 0
            THEN '💤 Ocioso (Nenhuma Viagem Registrada)'
        WHEN (COALESCE(AVG(p.peso_liquido_kg) / 1000.0, 0.0) / v.capacidade_carga_ton) >= 0.85
            THEN '🟢 Carga Plena / Alta Produtividade (>= 85%)'
        ELSE '🟡 Subutilizado (< 85% da Capacidade Nominal)'
    END AS diagnostico_operacional_frota
FROM veiculos_frota v
LEFT JOIN pesagens_coleta p
    ON v.id_veiculo = p.id_veiculo
GROUP BY
    v.id_veiculo,
    v.placa,
    v.modelo,
    v.tipo_veiculo,
    v.capacidade_carga_ton,
    v.empresa_operadora,
    v.status
ORDER BY
    status_mecanico ASC,
    taxa_aproveitamento_capacidade_pct DESC;


-- ============================================================================
-- CONSULTA 5 (C5): CUMPRIMENTO DE ITINERÁRIOS & DENSIDADE DE COLETA POR TURNO
-- ============================================================================
-- OBJETIVO DE NEGÓCIO:
-- Avaliar o desempenho operacional de cada rota cadastrada no município, comparando
-- os turnos de trabalho (Matutino, Vespertino e Noturno) quanto à tonelagem recolhida
-- e à extensão percorrida. Permite ao encarregado de logística urbana identificar
-- rotas longas com baixo rendimento (toneladas por quilômetro rodado) ou desequilíbrios
-- operacionais entre a coleta domiciliar e as rotas seletivas.
--
-- PÚBLICO-ALVO:
-- Engenheiro de Tráfego e Logística, Chefe de Operações de Limpeza Urbana.
--
-- COMPLEXIDADE TÉCNICA:
-- Agregação com múltiplos joins espaciais (bairro de origem e destino da rota),
-- cálculo da densidade de coleta (tonelada por quilômetro: ton/km), avaliação
-- de aderência de frequência semanal e categorização de eficiência logística.
-- ============================================================================

SELECT
    r.codigo_rota,
    r.tipo_coleta,
    r.turno,
    bo.nome_bairro AS bairro_origem,
    bd.nome_bairro AS bairro_destino,
    r.extensao_estimada_km,
    r.frequencia_semanal AS frequencia_planejada_dias_semana,
    COUNT(p.id_pesagem) AS total_viagens_executadas,
    ROUND(COALESCE(SUM(p.peso_liquido_kg) / 1000.0, 0.0), 2) AS volume_total_recolhido_ton,
    ROUND(
        COALESCE(SUM(p.peso_liquido_kg) / 1000.0, 0.0) / NULLIF(COUNT(p.id_pesagem), 0),
        2
    ) AS media_ton_por_viagem,
    ROUND(
        (COALESCE(SUM(p.peso_liquido_kg) / 1000.0, 0.0) / NULLIF(COUNT(p.id_pesagem), 0))
        / NULLIF(r.extensao_estimada_km, 0),
        3
    ) AS densidade_coleta_ton_por_km,
    CASE
        WHEN r.turno = 'Noturno' AND (COALESCE(SUM(p.peso_liquido_kg) / 1000.0, 0.0) / NULLIF(COUNT(p.id_pesagem), 0)) >= 10.0
            THEN '🌟 Rota Noturna de Alto Rendimento'
        WHEN r.tipo_coleta = 'Seletiva Reciclavel'
            THEN '♻️ Rota Seletiva Especializada'
        WHEN (COALESCE(SUM(p.peso_liquido_kg) / 1000.0, 0.0) / NULLIF(COUNT(p.id_pesagem), 0)) < 5.0
            THEN '⚠️ Baixo Rendimento por Viagem (< 5 ton)'
        ELSE '🟢 Operação Domiciliar Regular'
    END AS classificacao_itinerario
FROM rotas_coleta r
INNER JOIN bairros bo
    ON r.id_bairro_origem = bo.id_bairro
INNER JOIN bairros bd
    ON r.id_bairro_destino = bd.id_bairro
LEFT JOIN pesagens_coleta p
    ON r.id_rota = p.id_rota
GROUP BY
    r.id_rota,
    r.codigo_rota,
    r.tipo_coleta,
    r.turno,
    bo.nome_bairro,
    bd.nome_bairro,
    r.extensao_estimada_km,
    r.frequencia_semanal
ORDER BY
    volume_total_recolhido_ton DESC,
    densidade_coleta_ton_por_km DESC;

-- ============================================================================
-- FIM DAS CONSULTAS DO DASHBOARD OPERACIONAL (ITEM 7)
-- ============================================================================
