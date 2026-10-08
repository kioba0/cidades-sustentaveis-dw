-- ============================================================================
-- PROJETO ECOCIDADE — LABORATÓRIO DE DADOS PARA CIDADES SUSTENTÁVEIS (PBL)
-- DISCIPLINA: Tópicos Especiais em Banco de Dados — UNEB
-- DOCENTE: Prof. Me. Antônio José A. Cordeiro
-- ITEM 3 & 5 DO BAREMA: Modelagem Multidimensional (Data Warehouse / Star Schema)
-- SCRIPT: 03_dw_schema.sql
-- ============================================================================

SET NAMES utf8mb4;
SET TIME_ZONE = '-03:00';
SET FOREIGN_KEY_CHECKS = 0;

-- Criação e Seleção da Base Analítica (Data Warehouse)
CREATE DATABASE IF NOT EXISTS dw_ecocidade
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE dw_ecocidade;

-- ============================================================================
-- 1. TABELAS DE DIMENSÃO (CONFORMADAS)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1.1 DIMENSÃO TEMPO
-- Granularidade diária para análise temporal, sazonalidade e tendências.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS dim_tempo;
CREATE TABLE dim_tempo (
    sk_tempo INT PRIMARY KEY COMMENT 'Surrogate Key no formato YYYYMMDD ou sequencial',
    data_completa DATE NOT NULL UNIQUE,
    ano SMALLINT NOT NULL,
    mes TINYINT NOT NULL,
    nome_mes VARCHAR(20) NOT NULL,
    dia TINYINT NOT NULL,
    dia_semana TINYINT NOT NULL COMMENT '1=Domingo, 7=Sábado',
    nome_dia_semana VARCHAR(20) NOT NULL,
    trimestre TINYINT NOT NULL,
    semestre TINYINT NOT NULL,
    eh_fim_semana BOOLEAN NOT NULL
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE INDEX idx_dim_tempo_ano_mes ON dim_tempo (ano, mes);

-- ----------------------------------------------------------------------------
-- 1.2 DIMENSÃO BAIRRO
-- Dimensão geoespacial baseada nas Prefeituras-Bairro de Salvador.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS dim_bairro;
CREATE TABLE dim_bairro (
    sk_bairro INT AUTO_INCREMENT PRIMARY KEY,
    id_bairro_origem INT NOT NULL COMMENT 'Chave Natural do sistema operacional',
    nome_bairro VARCHAR(100) NOT NULL,
    regiao_administrativa VARCHAR(80) NOT NULL COMMENT 'Prefeitura-Bairro',
    faixa_populacional VARCHAR(40) NOT NULL,
    densidade_demografica VARCHAR(30) NOT NULL COMMENT 'Baixa, Média, Alta, Muito Alta',
    classe_renda VARCHAR(30) NOT NULL COMMENT 'Perfil socioeconômico predominante',
    CONSTRAINT uq_dim_bairro_origem UNIQUE (id_bairro_origem)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE INDEX idx_dim_bairro_regiao ON dim_bairro (regiao_administrativa);

-- ----------------------------------------------------------------------------
-- 1.3 DIMENSÃO TIPO DE RESÍDUO
-- Caracterização dos materiais, potencial de reciclagem e fator de impacto GEE.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS dim_tipo_residuo;
CREATE TABLE dim_tipo_residuo (
    sk_tipo_residuo INT AUTO_INCREMENT PRIMARY KEY,
    tipo_residuo_origem VARCHAR(50) NOT NULL UNIQUE,
    categoria_macro VARCHAR(40) NOT NULL COMMENT 'Domiciliar, Reciclável Seco, Entulho RCD, Orgânico',
    potencial_reciclagem_pct DECIMAL(5,2) NOT NULL COMMENT 'Percentual médio aproveitável',
    fator_emissao_ch4 DECIMAL(6,3) NOT NULL COMMENT 'Potencial de geração de metano em aterro (t CH4 / t resíduo)'
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE INDEX idx_dim_residuo_macro ON dim_tipo_residuo (categoria_macro);

-- ----------------------------------------------------------------------------
-- 1.4 DIMENSÃO VEÍCULO
-- Informações da frota de coleta, capacidade e operador logístico.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS dim_veiculo;
CREATE TABLE dim_veiculo (
    sk_veiculo INT AUTO_INCREMENT PRIMARY KEY,
    id_veiculo_origem INT NOT NULL,
    placa VARCHAR(10) NOT NULL,
    modelo VARCHAR(80) NOT NULL,
    tipo_veiculo VARCHAR(40) NOT NULL,
    empresa_operadora VARCHAR(100) NOT NULL,
    faixa_capacidade VARCHAR(30) NOT NULL,
    CONSTRAINT uq_dim_veiculo_origem UNIQUE (id_veiculo_origem)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE INDEX idx_dim_veiculo_tipo ON dim_veiculo (tipo_veiculo);

-- ----------------------------------------------------------------------------
-- 1.5 DIMENSÃO DESTINO
-- Instalação receptora e classificação de sustentabilidade (desvio de aterro).
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS dim_destino;
CREATE TABLE dim_destino (
    sk_destino INT AUTO_INCREMENT PRIMARY KEY,
    id_destino_origem INT NOT NULL,
    nome_instalacao VARCHAR(120) NOT NULL,
    tipo_instalacao VARCHAR(60) NOT NULL,
    bandeira_sustentavel VARCHAR(20) NOT NULL COMMENT 'Sustentavel (Reciclagem/Compostagem) vs Convencional (Aterro)',
    CONSTRAINT uq_dim_destino_origem UNIQUE (id_destino_origem)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE INDEX idx_dim_destino_sustentavel ON dim_destino (bandeira_sustentavel);

-- ----------------------------------------------------------------------------
-- 1.6 DIMENSÃO SEVERIDADE DE RISCO
-- Níveis de criticidade para atendimento a chamados de descarte irregular.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS dim_severidade;
CREATE TABLE dim_severidade (
    sk_severidade INT AUTO_INCREMENT PRIMARY KEY,
    nivel_severidade VARCHAR(50) NOT NULL UNIQUE,
    impacto_risco_geologico VARCHAR(10) NOT NULL COMMENT 'Sim ou Nao'
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- ============================================================================
-- 2. TABELAS DE FATOS (CONSTELAÇÃO DE FATOS)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 2.1 TABELA FATO: fato_coleta_residuos
-- Grão: Uma pesagem individual registrada na balança ao final de um turno de rota.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS fato_coleta_residuos;
CREATE TABLE fato_coleta_residuos (
    sk_fato_coleta BIGINT AUTO_INCREMENT PRIMARY KEY,
    sk_tempo INT NOT NULL,
    sk_bairro INT NOT NULL,
    sk_tipo_residuo INT NOT NULL,
    sk_veiculo INT NOT NULL,
    sk_destino INT NOT NULL,
    codigo_rota_dd VARCHAR(20) NOT NULL COMMENT 'Dimensão Degenerada: código da rota operacional',
    -- Métricas Analíticas
    peso_liquido_ton DECIMAL(8,3) NOT NULL,
    custo_destinacao_reais DECIMAL(10,2) NOT NULL,
    tempo_descarregamento_minutos INT NOT NULL,
    distancia_km DECIMAL(6,2) NOT NULL,
    emissoes_estimadas_co2_kg DECIMAL(8,2) NOT NULL,
    -- Restrições de Integridade Referencial
    CONSTRAINT fk_fato_coleta_tempo FOREIGN KEY (sk_tempo)
        REFERENCES dim_tempo (sk_tempo),
    CONSTRAINT fk_fato_coleta_bairro FOREIGN KEY (sk_bairro)
        REFERENCES dim_bairro (sk_bairro),
    CONSTRAINT fk_fato_coleta_residuo FOREIGN KEY (sk_tipo_residuo)
        REFERENCES dim_tipo_residuo (sk_tipo_residuo),
    CONSTRAINT fk_fato_coleta_veiculo FOREIGN KEY (sk_veiculo)
        REFERENCES dim_veiculo (sk_veiculo),
    CONSTRAINT fk_fato_coleta_destino FOREIGN KEY (sk_destino)
        REFERENCES dim_destino (sk_destino)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE INDEX idx_fato_coleta_tempo ON fato_coleta_residuos (sk_tempo);
CREATE INDEX idx_fato_coleta_bairro ON fato_coleta_residuos (sk_bairro);
CREATE INDEX idx_fato_coleta_residuo ON fato_coleta_residuos (sk_tipo_residuo);
CREATE INDEX idx_fato_coleta_destino ON fato_coleta_residuos (sk_destino);

-- ----------------------------------------------------------------------------
-- 2.2 TABELA FATO: fato_ocorrencias_descarte
-- Grão: Um chamado de descarte irregular de lixo/entulho registrado no 156.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS fato_ocorrencias_descarte;
CREATE TABLE fato_ocorrencias_descarte (
    sk_fato_ocorrencia BIGINT AUTO_INCREMENT PRIMARY KEY,
    sk_tempo_abertura INT NOT NULL,
    sk_tempo_atendimento INT NULL COMMENT 'Pode ser nulo caso o chamado ainda esteja aberto',
    sk_bairro INT NOT NULL,
    sk_veiculo_atendimento INT NULL COMMENT 'Pode ser nulo caso não tenha sido despachado veículo',
    sk_severidade INT NOT NULL,
    protocolo_cidadao_dd VARCHAR(30) NOT NULL COMMENT 'Dimensão Degenerada: Protocolo 156',
    status_chamado_dd VARCHAR(30) NOT NULL COMMENT 'Dimensão Degenerada: Status atual',
    -- Métricas Analíticas
    tempo_resolucao_horas DECIMAL(6,1) NULL COMMENT 'SLA decorrido entre abertura e conclusão',
    volume_estimado_m3 DECIMAL(6,2) NOT NULL,
    custo_remocao_reais DECIMAL(10,2) NOT NULL,
    -- Restrições de Integridade Referencial
    CONSTRAINT fk_fato_ocorrencias_tempo_abertura FOREIGN KEY (sk_tempo_abertura)
        REFERENCES dim_tempo (sk_tempo),
    CONSTRAINT fk_fato_ocorrencias_tempo_atendimento FOREIGN KEY (sk_tempo_atendimento)
        REFERENCES dim_tempo (sk_tempo),
    CONSTRAINT fk_fato_ocorrencias_bairro FOREIGN KEY (sk_bairro)
        REFERENCES dim_bairro (sk_bairro),
    CONSTRAINT fk_fato_ocorrencias_veiculo FOREIGN KEY (sk_veiculo_atendimento)
        REFERENCES dim_veiculo (sk_veiculo),
    CONSTRAINT fk_fato_ocorrencias_severidade FOREIGN KEY (sk_severidade)
        REFERENCES dim_severidade (sk_severidade)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE INDEX idx_fato_ocorrencias_abertura ON fato_ocorrencias_descarte (sk_tempo_abertura);
CREATE INDEX idx_fato_ocorrencias_bairro ON fato_ocorrencias_descarte (sk_bairro);
CREATE INDEX idx_fato_ocorrencias_severidade ON fato_ocorrencias_descarte (sk_severidade);

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- FIM DO SCRIPT DDL OLAP (DATA WAREHOUSE)
-- ============================================================================
