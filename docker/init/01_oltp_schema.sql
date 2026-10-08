-- ============================================================================
-- PROJETO ECOCIDADE — LABORATÓRIO DE DADOS PARA CIDADES SUSTENTÁVEIS (PBL)
-- DISCIPLINA: Tópicos Especiais em Banco de Dados — UNEB
-- DOCENTE: Prof. Me. Antônio José A. Cordeiro
-- ITEM 2 & 5 DO BAREMA: Modelagem e Criação do Ambiente Transacional OLTP
-- SCRIPT: 01_oltp_schema.sql
-- ============================================================================

-- Configurações de Ambiente
SET NAMES utf8mb4;
SET TIME_ZONE = '-03:00';
SET FOREIGN_KEY_CHECKS = 0;

-- Criação e Seleção da Base Operacional
CREATE DATABASE IF NOT EXISTS ecocidade_oltp
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE ecocidade_oltp;

-- ----------------------------------------------------------------------------
-- 1. TABELA: bairros
-- Entidade base para segmentação geoespacial e administrativa municipal.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS bairros;
CREATE TABLE bairros (
    id_bairro INT AUTO_INCREMENT PRIMARY KEY,
    nome_bairro VARCHAR(100) NOT NULL UNIQUE,
    regiao_administrativa VARCHAR(80) NOT NULL COMMENT 'Prefeitura-Bairro de Salvador (ex: Barra/Pituba, Cajazeiras, Subúrbio)',
    populacao_estimada INT NOT NULL,
    area_km2 DECIMAL(6,2) NOT NULL,
    renda_media_domiciliar DECIMAL(10,2) NULL COMMENT 'Renda média em reais segundo Censo/IBGE',
    data_cadastro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_bairros_populacao CHECK (populacao_estimada > 0),
    CONSTRAINT chk_bairros_area CHECK (area_km2 > 0)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE INDEX idx_bairros_regiao ON bairros (regiao_administrativa);

-- ----------------------------------------------------------------------------
-- 2. TABELA: destinos_finais
-- Instalações autorizadas de recebimento, triagem, reciclagem ou aterramento.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS destinos_finais;
CREATE TABLE destinos_finais (
    id_destino INT AUTO_INCREMENT PRIMARY KEY,
    nome_instalacao VARCHAR(120) NOT NULL UNIQUE,
    tipo_instalacao ENUM(
        'Aterro Sanitario Metropolitano',
        'Centro de Triagem Cooperativa',
        'Usina de Compostagem',
        'Ecoponto de Transbordo'
    ) NOT NULL,
    bairro_localizacao VARCHAR(100) NOT NULL,
    custo_tonelada_reais DECIMAL(8,2) NOT NULL COMMENT 'Custo de disposição ou remuneração de triagem por tonelada',
    capacidade_maxima_ton_mes DECIMAL(10,2) NOT NULL,
    licenca_ambiental VARCHAR(50) NOT NULL UNIQUE,
    status ENUM('Operacional', 'Em Reforma', 'Interditado') NOT NULL DEFAULT 'Operacional',
    CONSTRAINT chk_destinos_capacidade CHECK (capacidade_maxima_ton_mes > 0)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE INDEX idx_destinos_tipo ON destinos_finais (tipo_instalacao);

-- ----------------------------------------------------------------------------
-- 3. TABELA: cooperativas_reciclagem
-- Associações e cooperativas de catadores credenciadas no município.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS cooperativas_reciclagem;
CREATE TABLE cooperativas_reciclagem (
    id_cooperativa INT AUTO_INCREMENT PRIMARY KEY,
    id_bairro INT NOT NULL,
    nome_cooperativa VARCHAR(150) NOT NULL UNIQUE,
    cnpj VARCHAR(18) NOT NULL UNIQUE,
    capacidade_triagem_ton_dia DECIMAL(5,2) NOT NULL,
    qtd_catadores_associados INT NOT NULL,
    materiais_aceitos VARCHAR(200) NOT NULL COMMENT 'Tipos segregados: Plastico, Papelao, Vidro, Metal, Eletronicos',
    data_convenio DATE NOT NULL,
    CONSTRAINT fk_cooperativas_bairro FOREIGN KEY (id_bairro)
        REFERENCES bairros (id_bairro)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_coop_capacidade CHECK (capacidade_triagem_ton_dia > 0),
    CONSTRAINT chk_coop_catadores CHECK (qtd_catadores_associados > 0)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE INDEX idx_cooperativas_bairro ON cooperativas_reciclagem (id_bairro);

-- ----------------------------------------------------------------------------
-- 4. TABELA: pontos_coleta
-- Infraestrutura de descarte: PEVs, Ecopontos e monitoramento de lixões clandestinos.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS pontos_coleta;
CREATE TABLE pontos_coleta (
    id_ponto INT AUTO_INCREMENT PRIMARY KEY,
    id_bairro INT NOT NULL,
    nome_identificador VARCHAR(120) NOT NULL,
    tipo_ponto ENUM(
        'Ecoponto Central',
        'PEV Reciclaveis',
        'Lixeira Subterranea',
        'Ponto Viciado Clandestino'
    ) NOT NULL,
    logradouro VARCHAR(200) NOT NULL,
    capacidade_m3 DECIMAL(6,2) NOT NULL,
    data_instalacao DATE NOT NULL,
    status_operacional ENUM('Ativo', 'Interditado', 'Em Manutencao', 'Eliminado') NOT NULL DEFAULT 'Ativo',
    CONSTRAINT fk_pontos_bairro FOREIGN KEY (id_bairro)
        REFERENCES bairros (id_bairro)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_pontos_capacidade CHECK (capacidade_m3 >= 0)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE INDEX idx_pontos_bairro_tipo ON pontos_coleta (id_bairro, tipo_ponto);

-- ----------------------------------------------------------------------------
-- 5. TABELA: veiculos_frota
-- Caminhões coletores, caçambas e veículos de apoio operacional.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS veiculos_frota;
CREATE TABLE veiculos_frota (
    id_veiculo INT AUTO_INCREMENT PRIMARY KEY,
    placa VARCHAR(10) NOT NULL UNIQUE,
    modelo VARCHAR(80) NOT NULL,
    tipo_veiculo ENUM(
        'Compactador Pesado',
        'Caminhao Cacamba',
        'Poliguindaste',
        'Veiculo Utilitario Leve'
    ) NOT NULL,
    capacidade_carga_ton DECIMAL(5,2) NOT NULL,
    empresa_operadora VARCHAR(100) NOT NULL COMMENT 'Ex: Limpurb Municipal, Consorcio Salvador Limpa',
    emissao_co2_km_g DECIMAL(6,2) NOT NULL COMMENT 'Emissão estimada em gramas de CO2 por quilômetro',
    ano_fabricacao YEAR NOT NULL,
    status ENUM('Operacional', 'Em Manutencao', 'Inativo') NOT NULL DEFAULT 'Operacional',
    CONSTRAINT chk_veiculos_capacidade CHECK (capacidade_carga_ton > 0),
    CONSTRAINT chk_veiculos_emissao CHECK (emissao_co2_km_g >= 0)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE INDEX idx_veiculos_tipo ON veiculos_frota (tipo_veiculo);
CREATE INDEX idx_veiculos_status ON veiculos_frota (status);

-- ----------------------------------------------------------------------------
-- 6. TABELA: rotas_coleta
-- Itinerários de coleta domiciliar, seletiva e de entulho.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS rotas_coleta;
CREATE TABLE rotas_coleta (
    id_rota INT AUTO_INCREMENT PRIMARY KEY,
    codigo_rota VARCHAR(20) NOT NULL UNIQUE,
    id_bairro_origem INT NOT NULL,
    id_bairro_destino INT NOT NULL,
    turno ENUM('Matutino', 'Vespertino', 'Noturno') NOT NULL,
    tipo_coleta ENUM(
        'Domiciliar Convencional',
        'Seletiva Reciclavel',
        'Entulho e Volumosos',
        'Hospitalar'
    ) NOT NULL,
    frequencia_semanal INT NOT NULL,
    extensao_estimada_km DECIMAL(6,2) NOT NULL,
    CONSTRAINT fk_rotas_bairro_origem FOREIGN KEY (id_bairro_origem)
        REFERENCES bairros (id_bairro)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_rotas_bairro_destino FOREIGN KEY (id_bairro_destino)
        REFERENCES bairros (id_bairro)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_rotas_freq CHECK (frequencia_semanal BETWEEN 1 AND 7),
    CONSTRAINT chk_rotas_extensao CHECK (extensao_estimada_km > 0)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE INDEX idx_rotas_turnos ON rotas_coleta (turno, tipo_coleta);

-- ----------------------------------------------------------------------------
-- 7. TABELA: pesagens_coleta
-- Registro individual na balança rodoviária na entrada das centrais de destinação.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS pesagens_coleta;
CREATE TABLE pesagens_coleta (
    id_pesagem BIGINT AUTO_INCREMENT PRIMARY KEY,
    id_veiculo INT NOT NULL,
    id_rota INT NOT NULL,
    id_destino INT NOT NULL,
    data_hora_pesagem DATETIME NOT NULL,
    peso_bruto_kg DECIMAL(9,2) NOT NULL,
    tara_kg DECIMAL(9,2) NOT NULL,
    peso_liquido_kg DECIMAL(9,2) GENERATED ALWAYS AS (peso_bruto_kg - tara_kg) STORED,
    tipo_residuo ENUM(
        'Organico Domiciliar',
        'Reciclavel Seco',
        'Entulho RCD',
        'Poda e Jardinagem',
        'Rejeito Inerte'
    ) NOT NULL,
    km_odometro DECIMAL(9,2) NOT NULL,
    tempo_descarregamento_minutos INT NOT NULL,
    CONSTRAINT fk_pesagens_veiculo FOREIGN KEY (id_veiculo)
        REFERENCES veiculos_frota (id_veiculo)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_pesagens_rota FOREIGN KEY (id_rota)
        REFERENCES rotas_coleta (id_rota)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_pesagens_destino FOREIGN KEY (id_destino)
        REFERENCES destinos_finais (id_destino)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_pesagens_peso_bruto CHECK (peso_bruto_kg > 0),
    CONSTRAINT chk_pesagens_tara CHECK (tara_kg > 0),
    CONSTRAINT chk_pesagens_tempo CHECK (tempo_descarregamento_minutos >= 0)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE INDEX idx_pesagens_data ON pesagens_coleta (data_hora_pesagem);
CREATE INDEX idx_pesagens_tipo_residuo ON pesagens_coleta (tipo_residuo);
CREATE INDEX idx_pesagens_veiculo ON pesagens_coleta (id_veiculo);

-- ----------------------------------------------------------------------------
-- 8. TABELA: chamados_descarte_irregular
-- Reclamações de munícipes (156) relatando entulho clandestino e pontos viciados.
-- ----------------------------------------------------------------------------
DROP TABLE IF EXISTS chamados_descarte_irregular;
CREATE TABLE chamados_descarte_irregular (
    id_chamado BIGINT AUTO_INCREMENT PRIMARY KEY,
    protocolo_cidadao VARCHAR(30) NOT NULL UNIQUE,
    id_bairro INT NOT NULL,
    id_ponto_coleta INT NULL COMMENT 'Se associado a um ponto viciado monitorado',
    data_abertura DATETIME NOT NULL,
    data_atendimento DATETIME NULL,
    descricao_ocorrencia TEXT NOT NULL,
    volume_estimado_m3 DECIMAL(6,2) NOT NULL,
    severidade_risco ENUM(
        'Baixo',
        'Medio',
        'Critico / Risco Encosta ou Alagamento'
    ) NOT NULL,
    status ENUM('Aberto', 'Em Andamento', 'Concluido', 'Cancelado') NOT NULL DEFAULT 'Aberto',
    id_veiculo_atendimento INT NULL,
    CONSTRAINT fk_chamados_bairro FOREIGN KEY (id_bairro)
        REFERENCES bairros (id_bairro)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_chamados_ponto FOREIGN KEY (id_ponto_coleta)
        REFERENCES pontos_coleta (id_ponto)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_chamados_veiculo FOREIGN KEY (id_veiculo_atendimento)
        REFERENCES veiculos_frota (id_veiculo)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT chk_chamados_volume CHECK (volume_estimado_m3 > 0)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE INDEX idx_chamados_status_abertura ON chamados_descarte_irregular (status, data_abertura);
CREATE INDEX idx_chamados_bairro ON chamados_descarte_irregular (id_bairro);
CREATE INDEX idx_chamados_severidade ON chamados_descarte_irregular (severidade_risco);

SET FOREIGN_KEY_CHECKS = 1;

-- ============================================================================
-- FIM DO SCRIPT DDL OLTP
-- ============================================================================
