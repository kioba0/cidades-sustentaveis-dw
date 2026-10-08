# Origem e Linhagem dos Dados Abertos Governamentais

> **Projeto:** EcoCidade — Laboratório de Dados para Cidades Sustentáveis (PBL)  
> **Disciplina:** Tópicos Especiais em Banco de Dados — UNEB  
> **Docente:** Prof. Me. Antônio José A. Cordeiro  
> **Conjunto de Dados:** Central de Atendimento 156 (Limpeza Urbana, Remoção de Entulho e Coleta)

---

## 1. Fonte Oficial de Extração

* **Órgão Produtor:** Empresa de Limpeza Urbana (EMLURB) / Prefeitura Municipal.
* **Portal de Acesso:** [Portal de Dados Abertos do Recife](https://dados.recife.pe.gov.br) (Referência Nacional em Dados Abertos de Zeladoria Urbana).
* **Dataset:** *Central de Atendimento de Serviços da Emlurb – 156 (Série Histórica Oficial).*
* **URL do Recurso Baixado:** [Download Direto CSV](https://dados.recife.pe.gov.br/dataset/331e88a9-d878-464b-b0bb-cb803d7091b3/resource/031c3ad3-265f-4d9c-830a-7d1f85f830fa/download/2024-central-de-atendimento-de-servicos-da-emlurb-156.csv)
* **Formato Original:** Arquivo delimitado por ponto e vírgula (`;`), codificação UTF-8, contendo **108.083 registros brutos** e 18,5 MB.
* **Licença:** *Open Data Commons Open Database License (ODbL)* / Domínio Público Governamental.

---

## 2. Estrutura das Variáveis Originais

| Coluna Original | Tipo | Descrição no Portal Governamental |
|---|---|---|
| `GRUPOSERVICO_DESCRICAO` | Texto | Macroárea do serviço ('LIMPEZA URBANA', 'COLETA URBANA', 'DENUNCIAS') |
| `SERVICO_DESCRICAO` | Texto | Tipo da demanda ('REMOCAO DE ENTULHOS', 'REGULARIZAR COLETA DOMICILIAR', 'IMP. COLETA SELETIVA') |
| `LOGRADOURO` | Texto | Rua, avenida ou travessa onde ocorreu o fato |
| `NUMERO` | Texto | Numeração predial ou 'SN' |
| `BAIRRO` | Texto | Nome oficial do bairro onde a solicitação foi registrada |
| `RPA` | Numérico | Região Político-Administrativa (equivalente às Prefeituras-Bairro de Salvador) |
| `DATA_DEMANDA` | Data (ISO) | Data em que o cidadão registrou a ocorrência no canal 156 |
| `SITUACAO` | Texto | Estado do chamado ('ATENDIDA', 'PENDENTE', 'EM ANDAMENTO') |
| `DATA_ULT_SITUACAO` | Data (ISO) | Data em que a equipe operacional concluiu o atendimento |
| `latitude`, `longitude` | Numérico | Coordenadas georreferenciadas da ocorrência |

---

## 3. Pipeline de Ingestão & Enriquecimento (`ingestar_dados_reais.py`)

1. **Filtragem Temática:** Extração exclusiva das **11.622 solicitações** reais focadas estritamente em resíduos sólidos (`REMOCAO DE ENTULHOS`, `COLETA DOMICILIAR`, `COLETA SELETIVA` e `RECLAMACAO LIMPEZA URBANA`).
2. **Amostragem Estratificada:** Seleção de **1.000 chamados reais** distribuídos ao longo do período.
3. **Cálculo de SLA Real:** Derivação da métrica analítica de resolução em horas:
   $$\text{SLA (Horas)} = \text{TIMESTAMPDIFF(MINUTE, data\_demanda, data\_ult\_situacao)} / 60.0$$
4. **Carga Transacional (OLTP):** Inserção direta na tabela `ecocidade_oltp.chamados_descarte_irregular` com logradouro real, datas reais e status reais.
5. **Carga Dimensional (DW):** Propagação automática via `sql/04_etl_pipeline.sql` para a tabela `dw_ecocidade.fato_ocorrencias_descarte`.
