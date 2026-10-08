-- ============================================================================
-- PROJETO ECOCIDADE — LABORATÓRIO DE DADOS PARA CIDADES SUSTENTÁVEIS (PBL)
-- DISCIPLINA: Tópicos Especiais em Banco de Dados — UNEB
-- DOCENTE: Prof. Me. Antônio José A. Cordeiro
-- ITEM 5 DO BAREMA: Pipeline de ETL (Extração, Transformação e Carga)
-- SCRIPT: 04_etl_pipeline.sql
-- ============================================================================

USE dw_ecocidade;
SET NAMES utf8mb4;
SET TIME_ZONE = '-03:00';
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------------------------------------------------------
-- 1. ETL: POPULAÇÃO DA DIMENSÃO TEMPO (2024 a 2026)
-- ----------------------------------------------------------------------------
TRUNCATE TABLE dim_tempo;

DELIMITER $$
DROP PROCEDURE IF EXISTS sp_gerar_dim_tempo$$
CREATE PROCEDURE sp_gerar_dim_tempo(IN dt_inicio DATE, IN dt_fim DATE)
BEGIN
    DECLARE dt_atual DATE;
    SET dt_atual = dt_inicio;
    
    WHILE dt_atual <= dt_fim DO
        INSERT INTO dim_tempo (
            sk_tempo,
            data_completa,
            ano,
            mes,
            nome_mes,
            dia,
            dia_semana,
            nome_dia_semana,
            trimestre,
            semestre,
            eh_fim_semana
        ) VALUES (
            CAST(DATE_FORMAT(dt_atual, '%Y%m%d') AS UNSIGNED),
            dt_atual,
            YEAR(dt_atual),
            MONTH(dt_atual),
            CASE MONTH(dt_atual)
                WHEN 1 THEN 'Janeiro' WHEN 2 THEN 'Fevereiro' WHEN 3 THEN 'Março'
                WHEN 4 THEN 'Abril' WHEN 5 THEN 'Maio' WHEN 6 THEN 'Junho'
                WHEN 7 THEN 'Julho' WHEN 8 THEN 'Agosto' WHEN 9 THEN 'Setembro'
                WHEN 10 THEN 'Outubro' WHEN 11 THEN 'Novembro' WHEN 12 THEN 'Dezembro'
            END,
            DAY(dt_atual),
            DAYOFWEEK(dt_atual),
            CASE DAYOFWEEK(dt_atual)
                WHEN 1 THEN 'Domingo' WHEN 2 THEN 'Segunda-feira' WHEN 3 THEN 'Terça-feira'
                WHEN 4 THEN 'Quarta-feira' WHEN 5 THEN 'Quinta-feira' WHEN 6 THEN 'Sexta-feira'
                WHEN 7 THEN 'Sábado'
            END,
            QUARTER(dt_atual),
            CASE WHEN MONTH(dt_atual) <= 6 THEN 1 ELSE 2 END,
            CASE WHEN DAYOFWEEK(dt_atual) IN (1, 7) THEN TRUE ELSE FALSE END
        );
        SET dt_atual = DATE_ADD(dt_atual, INTERVAL 1 DAY);
    END WHILE;
END$$
DELIMITER ;

CALL sp_gerar_dim_tempo('2024-01-01', '2026-12-31');
DROP PROCEDURE IF EXISTS sp_gerar_dim_tempo;

-- ----------------------------------------------------------------------------
-- 2. ETL: CARGA DA DIMENSÃO BAIRRO
-- ----------------------------------------------------------------------------
TRUNCATE TABLE dim_bairro;

INSERT INTO dim_bairro (
    id_bairro_origem,
    nome_bairro,
    regiao_administrativa,
    faixa_populacional,
    densidade_demografica,
    classe_renda
)
SELECT 
    id_bairro,
    nome_bairro,
    regiao_administrativa,
    CASE 
        WHEN populacao_estimada < 25000 THEN 'Pequeno Porte (<25k hab)'
        WHEN populacao_estimada <= 50000 THEN 'Medio Porte (25k-50k hab)'
        ELSE 'Grande Porte (>50k hab)'
    END AS faixa_populacional,
    CASE 
        WHEN (populacao_estimada / area_km2) < 5000 THEN 'Baixa Densidade'
        WHEN (populacao_estimada / area_km2) <= 10000 THEN 'Media Densidade'
        ELSE 'Alta Densidade'
    END AS densidade_demografica,
    CASE 
        WHEN renda_media_domiciliar < 2000 THEN 'Vulnerabilidade Social Alta'
        WHEN renda_media_domiciliar < 4000 THEN 'Media Baixa'
        WHEN renda_media_domiciliar < 7000 THEN 'Media Alta'
        ELSE 'Classe Alta'
    END AS classe_renda
FROM ecocidade_oltp.bairros;

-- ----------------------------------------------------------------------------
-- 3. ETL: CARGA DA DIMENSÃO TIPO DE RESÍDUO
-- ----------------------------------------------------------------------------
TRUNCATE TABLE dim_tipo_residuo;

INSERT INTO dim_tipo_residuo (
    tipo_residuo_origem,
    categoria_macro,
    potencial_reciclagem_pct,
    fator_emissao_ch4
) VALUES
('Organico Domiciliar', 'Organico', 10.00, 0.085),
('Reciclavel Seco', 'Reciclavel Seco', 85.00, 0.005),
('Entulho RCD', 'Entulho RCD', 45.00, 0.001),
('Poda e Jardinagem', 'Organico', 30.00, 0.050),
('Rejeito Inerte', 'Rejeito', 5.00, 0.020);

-- ----------------------------------------------------------------------------
-- 4. ETL: CARGA DA DIMENSÃO VEÍCULO
-- ----------------------------------------------------------------------------
TRUNCATE TABLE dim_veiculo;

INSERT INTO dim_veiculo (
    id_veiculo_origem,
    placa,
    modelo,
    tipo_veiculo,
    empresa_operadora,
    faixa_capacidade
)
SELECT 
    id_veiculo,
    placa,
    modelo,
    tipo_veiculo,
    empresa_operadora,
    CASE 
        WHEN capacidade_carga_ton < 5.00 THEN 'Leve (< 5t)'
        WHEN capacidade_carga_ton <= 15.00 THEN 'Medio (5t a 15t)'
        ELSE 'Pesado (> 15t)'
    END AS faixa_capacidade
FROM ecocidade_oltp.veiculos_frota;

-- ----------------------------------------------------------------------------
-- 5. ETL: CARGA DA DIMENSÃO DESTINO
-- ----------------------------------------------------------------------------
TRUNCATE TABLE dim_destino;

INSERT INTO dim_destino (
    id_destino_origem,
    nome_instalacao,
    tipo_instalacao,
    bandeira_sustentavel
)
SELECT 
    id_destino,
    nome_instalacao,
    tipo_instalacao,
    CASE 
        WHEN tipo_instalacao IN ('Centro de Triagem Cooperativa', 'Usina de Compostagem', 'Ecoponto de Transbordo') 
            THEN 'Sustentavel (Reciclagem)'
        ELSE 'Convencional (Aterro)'
    END AS bandeira_sustentavel
FROM ecocidade_oltp.destinos_finais;

-- ----------------------------------------------------------------------------
-- 6. ETL: CARGA DA DIMENSÃO SEVERIDADE
-- ----------------------------------------------------------------------------
TRUNCATE TABLE dim_severidade;

INSERT INTO dim_severidade (nivel_severidade, impacto_risco_geologico) VALUES
('Baixo', 'Nao'),
('Medio', 'Nao'),
('Critico / Risco Encosta ou Alagamento', 'Sim');

-- ----------------------------------------------------------------------------
-- 7. ETL: CARGA DA TABELA FATO: fato_coleta_residuos
-- ----------------------------------------------------------------------------
TRUNCATE TABLE fato_coleta_residuos;

INSERT INTO fato_coleta_residuos (
    sk_tempo,
    sk_bairro,
    sk_tipo_residuo,
    sk_veiculo,
    sk_destino,
    codigo_rota_dd,
    peso_liquido_ton,
    custo_destinacao_reais,
    tempo_descarregamento_minutos,
    distancia_km,
    emissoes_estimadas_co2_kg
)
SELECT 
    dt.sk_tempo,
    db.sk_bairro,
    dtr.sk_tipo_residuo,
    dv.sk_veiculo,
    dd.sk_destino,
    r.codigo_rota AS codigo_rota_dd,
    ROUND(p.peso_liquido_kg / 1000.0, 3) AS peso_liquido_ton,
    ROUND((p.peso_liquido_kg / 1000.0) * dest.custo_tonelada_reais, 2) AS custo_destinacao_reais,
    p.tempo_descarregamento_minutos,
    r.extensao_estimada_km AS distancia_km,
    ROUND((r.extensao_estimada_km * v.emissao_co2_km_g) / 1000.0, 2) AS emissoes_estimadas_co2_kg
FROM ecocidade_oltp.pesagens_coleta p
INNER JOIN ecocidade_oltp.rotas_coleta r ON p.id_rota = r.id_rota
INNER JOIN ecocidade_oltp.destinos_finais dest ON p.id_destino = dest.id_destino
INNER JOIN ecocidade_oltp.veiculos_frota v ON p.id_veiculo = v.id_veiculo
-- Resolução de Surrogate Keys
INNER JOIN dim_tempo dt ON dt.data_completa = DATE(p.data_hora_pesagem)
INNER JOIN dim_bairro db ON db.id_bairro_origem = r.id_bairro_origem
INNER JOIN dim_tipo_residuo dtr ON dtr.tipo_residuo_origem = p.tipo_residuo
INNER JOIN dim_veiculo dv ON dv.id_veiculo_origem = p.id_veiculo
INNER JOIN dim_destino dd ON dd.id_destino_origem = p.id_destino;

-- ----------------------------------------------------------------------------
-- 8. ETL: CARGA DA TABELA FATO: fato_ocorrencias_descarte
-- ----------------------------------------------------------------------------
TRUNCATE TABLE fato_ocorrencias_descarte;

INSERT INTO fato_ocorrencias_descarte (
    sk_tempo_abertura,
    sk_tempo_atendimento,
    sk_bairro,
    sk_veiculo_atendimento,
    sk_severidade,
    protocolo_cidadao_dd,
    status_chamado_dd,
    tempo_resolucao_horas,
    volume_estimado_m3,
    custo_remocao_reais
)
SELECT 
    dt_ab.sk_tempo AS sk_tempo_abertura,
    dt_at.sk_tempo AS sk_tempo_atendimento,
    db.sk_bairro,
    dv.sk_veiculo AS sk_veiculo_atendimento,
    ds.sk_severidade,
    c.protocolo_cidadao AS protocolo_cidadao_dd,
    c.status AS status_chamado_dd,
    CASE 
        WHEN c.data_atendimento IS NOT NULL 
            THEN ROUND(TIMESTAMPDIFF(MINUTE, c.data_abertura, c.data_atendimento) / 60.0, 1)
        ELSE NULL 
    END AS tempo_resolucao_horas,
    c.volume_estimado_m3,
    ROUND(c.volume_estimado_m3 * 85.00, 2) AS custo_remocao_reais
FROM ecocidade_oltp.chamados_descarte_irregular c
INNER JOIN dim_tempo dt_ab ON dt_ab.data_completa = DATE(c.data_abertura)
LEFT JOIN dim_tempo dt_at ON dt_at.data_completa = DATE(c.data_atendimento)
INNER JOIN dim_bairro db ON db.id_bairro_origem = c.id_bairro
LEFT JOIN dim_veiculo dv ON dv.id_veiculo_origem = c.id_veiculo_atendimento
INNER JOIN dim_severidade ds ON ds.nivel_severidade = c.severidade_risco;

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- FIM DO SCRIPT DE ETL
-- ============================================================================
