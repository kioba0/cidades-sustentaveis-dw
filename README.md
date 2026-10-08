# Laboratório de Dados para Cidades Sustentáveis (PBL)

> **Disciplina:** Tópicos Especiais em Banco de Dados  
> **Instituição:** Universidade do Estado da Bahia (UNEB)  
> **Docente:** Prof. Me. Antônio José A. Cordeiro  
> **Tema Central:** Ecossistema de Dados Open-Source para Gestão Pública Municipal & ODS 11  
> **Metodologia:** Problem-Based Learning (PBL)

---

## 📌 Visão Geral do Projeto

Este repositório contém o desenvolvimento de um ecossistema completo de engenharia e análise de dados focado em solucionar desafios críticos da **gestão pública municipal**, concebido sob a ótica da **ODS 11 – Cidades e Comunidades Sustentáveis** (Agenda 2030 da ONU).

O projeto aplica a metodologia ativa **Problem-Based Learning (PBL)**, conectando teoria de bancos de dados a tomadas de decisão reais em prefeituras através de:
1. Arquitetura transacional (**OLTP**) modelada para operações de serviços públicos.
2. Arquitetura analítica multidimensional (**OLAP / Data Warehouse**) orientada a indicadores de sustentabilidade urbana.
3. Pipeline automatizado de Extração, Transformação e Carga (**ETL**).
4. Técnicas de **Mineração de Dados** e **Análise Exploratória de Dados (AED)**.
5. Painéis analíticos piramidais (níveis **Operacional**, **Tático** e **Estratégico**).
6. Formulação de diretrizes executivas através de um **Plano de Ação 5W2H**.

---

## 🏛️ Barema de Avaliação do Projeto (10,0 Pontos)

| Item | Entregável | Descrição | Status |
|:---:|---|---|:---:|
| **1** | **Contextualização** | Texto com requisitos, problematização e justificativa da ODS 11 | 🟡 Em Planejamento |
| **2** | **Modelagem OLTP** | Mínimo de 6 entidades em modelo relacional normalizado | 🟡 Em Planejamento |
| **3** | **Modelagem OLAP** | Modelo dimensional (Star Schema / Constelação) | 🟡 Em Planejamento |
| **4** | **Dicionário de Dados** | Documentação exaustiva de atributos, tipos, chaves e restrições | 🟡 Em Planejamento |
| **5** | **Script de Construção** | Scripts SQL completos para criação dos ambientes OLTP e OLAP | 🟡 Em Planejamento |
| **6** | **Análise Exploratória (AED)** | Mineração de dados aplicada à resolução do problema municipal | ⚪ Não Iniciado |
| **7** | **Dashboard Operacional** | Mínimo de 5 consultas SQL (enunciado + código) de nível operacional | ⚪ Não Iniciado |
| **8** | **Dashboard Tático** | Mínimo de 5 consultas SQL (enunciado + código) de nível tático | ⚪ Não Iniciado |
| **9** | **Dashboard Estratégico** | Mínimo de 5 consultas SQL (enunciado + código) de nível estratégico | ⚪ Não Iniciado |
| **10** | **Plano de Ação (5W2H)** | Plano de ação orientado por dados para suporte à gestão | ⚪ Não Iniciado |

---

## 🗓️ Cronograma & Marcos de Entrega

* **Feedback Parcial (20% da avaliação):** `19/10/2026`
  * Entrega e validação obrigatória dos **itens 1 a 5**.
* **Entrega Final & Apresentação (40% da nota):** `06/11/2026`
  * Entrega completa dos 10 itens e apresentação técnica perante banca examinadora.

---

## 📁 Estrutura do Repositório

```
lab_dados/
├── README.md                      # Documentação central do projeto (este arquivo)
├── .gitignore                     # Filtros para artefatos gerados, caches e segredos
│
├── materiais/                     # Materiais de referência e enunciados do docente
│   ├── Projeto_TEBD_Laboratorio de Dados para Cidades Sustentaveis-PBL.docx
│   ├── enunciado_pbl.md           # Transcrição integral do enunciado e barema
│   ├── ods_onu.jpeg               # Painel dos 17 Objetivos de Desenvolvimento Sustentável
│   └── fluxo_pbl_artigo.png       # Fluxo metodológico PBL (Cordeiro et al., 2018)
│
├── docs/                          # Documentações analíticas e conceituais
│   ├── 01_contextualizacao.md     # Problematização, requisitos e vínculos ODS (Item 1)
│   ├── 02_dicionario_dados.md     # Dicionário de dados OLTP e OLAP (Item 4)
│   ├── 03_mineracao_dados_aed.md  # Análise Exploratória e Mineração de Dados (Item 6)
│   └── 04_plano_acao_5w2h.md      # Plano de Ação 5W2H (Item 10)
│
├── diagramas/                     # Modelagens conceituais e lógicas
│   ├── modelo_oltp.puml           # Diagrama relacional OLTP (Item 2)
│   └── modelo_olap.puml           # Diagrama dimensional Star Schema (Item 3)
│
├── sql/                           # Scripts SQL executáveis
│   ├── 01_oltp_schema.sql         # DDL do banco operacional (Item 5)
│   ├── 02_oltp_seed.sql           # Carga de dados operacionais
│   ├── 03_dw_schema.sql           # DDL do Data Warehouse (Item 5)
│   ├── 04_etl_pipeline.sql        # Procedimentos de ETL e transformação
│   ├── 05_consultas_operacional.sql # 5 Consultas operacionais (Item 7)
│   ├── 06_consultas_tatico.sql     # 5 Consultas táticas (Item 8)
│   └── 07_consultas_estrategico.sql# 5 Consultas estratégicas (Item 9)
│
└── docker/                        # Orquestração do ambiente de execução (Zero-Touch)
    ├── docker-compose.yml         # MySQL 8.0 + Metabase BI
    └── init/                      # Cargas automatizadas de inicialização
```

---

## 🔬 Referencial Metodológico PBL

A condução deste projeto adota a metodologia de 8 etapas documentada no artigo:

> Martins, V. F., Sampaio, P. N. M., Cordeiro, A. J. A., & Viana, B. F. (2018).  
> **Implementing a Data Network Infrastructure Course using a Problem-based Learning Methodology**.  
> *Journal of Information Systems Engineering & Management*, 3(2), 10.  
> DOI: [10.20897/jisem.201810](https://doi.org/10.20897/jisem.201810)
