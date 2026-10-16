# Origem e Linhagem dos Dados Abertos Governamentais

> **Projeto:** EcoCidade — Laboratório de Dados para Cidades Sustentáveis (PBL)  
> **Disciplina:** Tópicos Especiais em Banco de Dados — UNEB  
> **Docente:** Prof. Me. Antônio José A. Cordeiro  
> **Conjunto de Dados:** Central de Atendimento 156 (Limpeza Urbana, Remoção de Entulho e Coleta)  
> **Metodologia de Engenharia de Dados:** Calibração Empírica por Cidade-Espelho (*Proxy Urbano / Transferência Empírica*)

---

## 1. Contexto Metodológico & Escolha da Fonte

Para que a solução possua relevância institucional e aderência acadêmica na Universidade do Estado da Bahia (UNEB), o projeto modela a infraestrutura territorial da cidade de **Salvador - BA** (Prefeituras-Bairro, relevo acentuado de encostas e bairros tradicionais como Barra, Brotas, Liberdade, Subúrbio e Cajazeiras).

### O Desafio de Acesso a Microdados em Salvador:
Embora a Prefeitura Municipal de Salvador opere a Ouvidoria e o canal *Fala Salvador 156* através da Empresa de Limpeza Urbana de Salvador (Limpurb), os portais municipais abertos (*Salvador Dados* e Transparência) disponibilizam apenas mapas interativos em ArcGIS, guias de horários de coleta e relatórios orçamentários agregados. Não há disponibilização pública ativa em microdados tabulares (CSV/API) de cada solicitação individual contendo carimbos de tempo de abertura, despacho, fechamento e volume para cálculo de SLA de atendimento.

### A Solução: Calibração Empírica por Cidade-Espelho
Para municiar o Data Warehouse e o algoritmo de Mineração de Dados (K-Means) com volumetria pesada e padrões operacionais verossímeis, adotou-se o modelo de **Transferência Empírica (*Grounded Synthetic Proxy*)**:
* Adotou-se a base histórica oficial da **EMLURB (Recife - PE)** — uma das capitais mais premiadas do país em transparência pública de dados de zeladoria urbana.
* O Recife compartilha com Salvador características operacionais cruciais: grande capital litorânea nordestina, clima tropical úmido com quadra chuvosa concentrada, densidade populacional heterogênea e desafios severos de pontos viciados de entulho em comunidades de encosta e canais.
* As variáveis estatísticas (curvas de sazonalidade, distribuição horária de chamados, prazos reais de resolução/SLA em horas, proporções de serviços e volumetria) foram extraídas da base da EMLURB e **projetadas com exatidão sobre a malha de 16 bairros e logradouros reais de Salvador**.

---

## 2. Fonte Oficial dos Dados Brutos de Treinamento

* **Órgão Produtor:** Empresa de Limpeza Urbana (EMLURB) / Prefeitura Municipal do Recife.
* **Portal de Acesso:** [Portal de Dados Abertos do Recife](https://dados.recife.pe.gov.br).
* **Dataset:** *Central de Atendimento de Serviços da Emlurb – 156 (Série Histórica Oficial).*
* **URL do Recurso Baixado:** [Download Direto CSV](https://dados.recife.pe.gov.br/dataset/331e88a9-d878-464b-b0bb-cb803d7091b3/resource/031c3ad3-265f-4d9c-830a-7d1f85f830fa/download/2024-central-de-atendimento-de-servicos-da-emlurb-156.csv)
* **Formato Original:** Arquivo delimitado por ponto e vírgula (`;`), codificação UTF-8, contendo **108.083 registros brutos** e 18,5 MB.
* **Licença:** *Open Data Commons Open Database License (ODbL)* / Domínio Público Governamental.

---

## 3. Variáveis Originais Extraídas

| Coluna Original | Tipo | Descrição no Portal Governamental |
|---|---|---|
| `GRUPOSERVICO_DESCRICAO` | Texto | Macroárea do serviço ('LIMPEZA URBANA', 'COLETA URBANA', 'DENUNCIAS') |
| `SERVICO_DESCRICAO` | Texto | Tipo da demanda ('REMOCAO DE ENTULHOS', 'REGULARIZAR COLETA DOMICILIAR', 'IMP. COLETA SELETIVA') |
| `LOGRADOURO` | Texto | Logradouro onde ocorreu o fato |
| `NUMERO` | Texto | Numeração predial ou 'SN' |
| `BAIRRO` | Texto | Nome do bairro de registro original |
| `DATA_DEMANDA` | Data/Hora (ISO) | Timestamp em que o munícipe registrou o chamado no canal 156 |
| `SITUACAO` | Texto | Estado do chamado ('ATENDIDA', 'PENDENTE', 'EM ANDAMENTO') |
| `DATA_ULT_SITUACAO` | Data/Hora (ISO) | Timestamp em que a equipe operacional concluiu a execução |
| `latitude`, `longitude` | Numérico | Coordenadas georreferenciadas da ocorrência |

---

## 4. Pipeline de Ingestão & Projeção Territorial (`ingestar_dados_reais.py`)

1. **Filtragem Temática:** Extração exclusiva das **11.622 solicitações** reais focadas estritamente em resíduos sólidos (`REMOCAO DE ENTULHOS`, `COLETA DOMICILIAR`, `COLETA SELETIVA` e `RECLAMACAO LIMPEZA URBANA`).
2. **Amostragem Estratificada:** Seleção de **1.000 chamados reais** preservando a sazonalidade anual de 2024.
3. **Cálculo e Preservação de SLA Real:**
   $$\text{SLA (Horas)} = \frac{\text{TIMESTAMPDIFF(MINUTE, data\_abertura, data\_atendimento)}}{60.0}$$
   *Chamados concluídos conservam o tempo exato de resposta medido no mundo real.*
4. **Projeção na Malha Urbana de Salvador:**
   * Cada chamado recebe um protocolo oficial no formato `SSA-156-2024-XXXXX` (*Fala Salvador*).
   * A chave estrangeira `id_bairro` aponta para um dos 16 bairros oficiais de Salvador (`Centro Histórico`, `Brotas`, `Barra`, `Pituba`, `Liberdade`, `São Caetano`, `Periperi`, `Paripe`, `Cajazeiras X`, `Itapuã`, etc.).
   * A descrição do chamado recebe um logradouro real do respectivo bairro (ex: *Ladeira dos Galés* em Brotas, *Estrada da Paciência* em Cajazeiras, *Av. Afrânio Peixoto* em Periperi).
   * Bairros de encosta e alta vulnerabilidade recebem pesos calibrados para maior severidade de risco geológico e alagamento.
5. **Carga e Idempotência:**
   * Geração automática das instruções `INSERT` em `sql/02_oltp_seed.sql` e `docker/init/02_oltp_seed.sql`.
   * Propagação automática para o Data Warehouse (`dw_ecocidade.fato_ocorrencias_descarte`) pelo pipeline `sql/04_etl_pipeline.sql`.
