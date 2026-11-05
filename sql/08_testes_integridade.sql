-- ============================================================================
-- PROJETO ECOCIDADE — LABORATÓRIO DE DADOS PARA CIDADES SUSTENTÁVEIS (PBL)
-- DISCIPLINA: Tópicos Especiais em Banco de Dados — UNEB
-- DOCENTE: Prof. Me. Antônio José A. Cordeiro
-- SUÍTE DE TESTES AUTOMATIZADOS E ASSERÇÕES DE INTEGRIDADE (OLTP vs OLAP)
-- SCRIPT: 08_testes_integridade.sql
-- ============================================================================

USE dw_ecocidade;
SET NAMES utf8mb4;

DROP TEMPORARY TABLE IF EXISTS resultado_testes;
CREATE TEMPORARY TABLE resultado_testes (
    id_teste INT AUTO_INCREMENT PRIMARY KEY,
    categoria VARCHAR(40),
    descricao VARCHAR(120),
    esperado VARCHAR(60),
    obtido VARCHAR(60),
    status ENUM('✅ PASS', '❌ FAIL')
);

-- ----------------------------------------------------------------------------
-- TESTE 1: Paridade Volumétrica de Transações de Pesagem (OLTP vs DW)
-- ----------------------------------------------------------------------------
INSERT INTO resultado_testes (categoria, descricao, esperado, obtido, status)
SELECT 
    'Paridade de Carga ETL',
    'Total de Pesagens no OLTP igual a Total de Fatos em fato_coleta_residuos',
    CONCAT(count_oltp, ' registros'),
    CONCAT(count_dw, ' registros'),
    CASE WHEN count_oltp = count_dw AND count_dw > 0 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM (
    SELECT 
        (SELECT COUNT(*) FROM ecocidade_oltp.pesagens_coleta) AS count_oltp,
        (SELECT COUNT(*) FROM dw_ecocidade.fato_coleta_residuos) AS count_dw
) sub;

-- ----------------------------------------------------------------------------
-- TESTE 2: Paridade Volumétrica de Chamados do Cidadão 156 (OLTP vs DW)
-- ----------------------------------------------------------------------------
INSERT INTO resultado_testes (categoria, descricao, esperado, obtido, status)
SELECT 
    'Paridade de Carga ETL',
    'Total de Chamados 156 no OLTP igual a Total em fato_ocorrencias_descarte',
    CONCAT(count_oltp, ' registros'),
    CONCAT(count_dw, ' registros'),
    CASE WHEN count_oltp = count_dw AND count_dw > 0 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM (
    SELECT 
        (SELECT COUNT(*) FROM ecocidade_oltp.chamados_descarte_irregular) AS count_oltp,
        (SELECT COUNT(*) FROM dw_ecocidade.fato_ocorrencias_descarte) AS count_dw
) sub;

-- ----------------------------------------------------------------------------
-- TESTE 3: Integridade Referencial Estrita em fato_coleta_residuos (Zero Órfãos)
-- ----------------------------------------------------------------------------
INSERT INTO resultado_testes (categoria, descricao, esperado, obtido, status)
SELECT 
    'Integridade Referencial',
    'Ausência de Surrogate Keys órfãs em fato_coleta_residuos',
    '0 órfãos',
    CONCAT(total_orfaos, ' órfãos'),
    CASE WHEN total_orfaos = 0 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM (
    SELECT COUNT(*) AS total_orfaos
    FROM fato_coleta_residuos f
    LEFT JOIN dim_tempo dt ON f.sk_tempo = dt.sk_tempo
    LEFT JOIN dim_bairro db ON f.sk_bairro = db.sk_bairro
    LEFT JOIN dim_tipo_residuo dtr ON f.sk_tipo_residuo = dtr.sk_tipo_residuo
    LEFT JOIN dim_veiculo dv ON f.sk_veiculo = dv.sk_veiculo
    LEFT JOIN dim_destino dd ON f.sk_destino = dd.sk_destino
    WHERE dt.sk_tempo IS NULL 
       OR db.sk_bairro IS NULL 
       OR dtr.sk_tipo_residuo IS NULL 
       OR dv.sk_veiculo IS NULL 
       OR dd.sk_destino IS NULL
) sub;

-- ----------------------------------------------------------------------------
-- TESTE 4: Integridade Referencial Estrita em fato_ocorrencias_descarte (Zero Órfãos)
-- ----------------------------------------------------------------------------
INSERT INTO resultado_testes (categoria, descricao, esperado, obtido, status)
SELECT 
    'Integridade Referencial',
    'Ausência de Surrogate Keys órfãs em fato_ocorrencias_descarte (exceto atendimento pendente)',
    '0 órfãos',
    CONCAT(total_orfaos, ' órfãos'),
    CASE WHEN total_orfaos = 0 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM (
    SELECT COUNT(*) AS total_orfaos
    FROM fato_ocorrencias_descarte fo
    LEFT JOIN dim_tempo dt ON fo.sk_tempo_abertura = dt.sk_tempo
    LEFT JOIN dim_bairro db ON fo.sk_bairro = db.sk_bairro
    LEFT JOIN dim_severidade ds ON fo.sk_severidade = ds.sk_severidade
    WHERE dt.sk_tempo IS NULL 
       OR db.sk_bairro IS NULL 
       OR ds.sk_severidade IS NULL
) sub;

-- ----------------------------------------------------------------------------
-- TESTE 5: Sanidade das Métricas Físicas e Financeiras (Valores Não Negativos)
-- ----------------------------------------------------------------------------
INSERT INTO resultado_testes (categoria, descricao, esperado, obtido, status)
SELECT 
    'Consistência de Domínio',
    'Métricas analíticas estritamente positivas (peso, custo e volume)',
    '0 violações',
    CONCAT(violacoes, ' violações'),
    CASE WHEN violacoes = 0 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM (
    SELECT 
        (SELECT COUNT(*) FROM fato_coleta_residuos WHERE peso_liquido_ton <= 0 OR custo_destinacao_reais < 0) +
        (SELECT COUNT(*) FROM fato_ocorrencias_descarte WHERE volume_estimado_m3 <= 0 OR custo_remocao_reais < 0) AS violacoes
) sub;

-- ----------------------------------------------------------------------------
-- TESTE 6: Conformidade Dimensional Territorial (16 Bairros de Salvador)
-- ----------------------------------------------------------------------------
INSERT INTO resultado_testes (categoria, descricao, esperado, obtido, status)
SELECT 
    'Conformidade Geográfica',
    'Total de 16 Bairros Oficiais conformados na dim_bairro',
    '16 bairros',
    CONCAT(total_bairros, ' bairros'),
    CASE WHEN total_bairros = 16 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM (
    SELECT COUNT(*) AS total_bairros FROM dim_bairro
) sub;

-- ----------------------------------------------------------------------------
-- TESTE 7: Cobertura Temporal Plurianual (2023 a 2026)
-- ----------------------------------------------------------------------------
INSERT INTO resultado_testes (categoria, descricao, esperado, obtido, status)
SELECT 
    'Conformidade Temporal',
    'Dimensão tempo cobre período plurianual contínuo (2023 a 2026)',
    '1461 dias',
    CONCAT(total_dias, ' dias'),
    CASE WHEN total_dias = 1461 THEN '✅ PASS' ELSE '❌ FAIL' END
FROM (
    SELECT COUNT(*) AS total_dias FROM dim_tempo
) sub;

-- ----------------------------------------------------------------------------
-- EXIBIÇÃO DO RELATÓRIO CONSOLIDADO DE QUALIDADE DE DADOS
-- ----------------------------------------------------------------------------
SELECT 
    id_teste,
    categoria,
    descricao,
    esperado,
    obtido,
    status
FROM resultado_testes;

-- Resumo Geral
SELECT 
    COUNT(*) AS total_testes,
    SUM(CASE WHEN status = '✅ PASS' THEN 1 ELSE 0 END) AS testes_aprovados,
    SUM(CASE WHEN status = '❌ FAIL' THEN 1 ELSE 0 END) AS testes_com_falha,
    CASE 
        WHEN SUM(CASE WHEN status = '❌ FAIL' THEN 1 ELSE 0 END) = 0 
            THEN '🏆 SUCESSO ABSOLUTO: 100% DAS ASSERÇÕES APROVADAS'
        ELSE '⚠️ ATENÇÃO: HÁ FALHAS DE INTEGRIDADE A CORRIGIR'
    END AS veredito_final
FROM resultado_testes;
