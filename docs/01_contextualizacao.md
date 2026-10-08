# Item 1 — Contextualização, Problematização e Requisitos (EcoCidade)

> **Disciplina:** Tópicos Especiais em Banco de Dados  
> **Instituição:** Universidade do Estado da Bahia (UNEB)  
> **Docente:** Prof. Me. Antônio José A. Cordeiro  
> **Projeto:** EcoCidade — Laboratório de Dados para Cidades Sustentáveis  
> **Entregável:** Item 1 do Barema Oficial (Nota Máxima: 1,0 ponto)  
> **Repositório:** [`lab_dados/`](file:///home/kioba/Documents/Faculdade/9_SEMESTRE/Bancos/lab_dados/) ([kioba0/cidades-sustentaveis-dw](https://github.com/kioba0/cidades-sustentaveis-dw))

---

## 1. Introdução e Propósito do Projeto

O crescimento desordenado dos centros urbanos contemporâneos impõe desafios sem precedentes à administração pública municipal, especialmente no que tange à sustentabilidade ambiental, à saúde coletiva e à eficiência do gasto público. Dentre as competências essenciais de uma prefeitura, a gestão de **Resíduos Sólidos Urbanos (RSU)** destaca-se como uma das operações mais complexas e financeiramente onerosas da máquina pública.

O projeto **EcoCidade** surge como uma resposta tecnológica orientada a dados (*data-driven governance*), concebida no âmbito da metodologia ativa **Problem-Based Learning (PBL)**. Seu propósito é o desenvolvimento de um **ecossistema de banco de dados open-source** composto por camadas transacionais (**OLTP**) e analíticas multidimensionais (**OLAP / Data Warehouse**), integrado a rotinas de **Mineração de Dados** e **Business Intelligence (BI)**.

A solução visa instrumentalizar gestores públicos com diagnósticos precisos, visões preditivas e indicadores de sustentabilidade urbana para mitigar o descarte clandestino, reduzir custos de transporte e aterro, e maximizar a triagem de recicláveis em cooperativas locais.

---

## 2. Problematização do Cenário Municipal (Salvador - BA)

Para conferir aderência prática e validação empírica imediata, o projeto ancora seu domínio territorial e operacional na cidade de **Salvador, Bahia** — a terceira capital mais populosa do Brasil, com aproximadamente 2,4 milhões de habitantes distribuídos em relevo topográfico singular marcado por espigões, vales, encostas acentuadas e extensa orla marítima.

A estrutura administrativa municipal é dividida em **10 Prefeituras-Bairro** (Centro/Brotas, Subúrbio Ferroviário/Ilhas, Cajazeiras, Itapuã, Pau da Lima, Cabula/Tancredo Neves, Barra/Pituba, Liberdade/São Caetano, Cidade Baixa e Valéria). Essa heterogeneidade socioespacial gera padrões distintos de descarte e desafios logísticos crônicos, estruturados em quatro gargalos fundamentais:

### 2.1 Dreno Orçamentário com Disposição em Aterros Sanitários
A prefeitura municipal remunera consórcios operadores do aterro sanitário e empresas de transporte por tonelada recolhida e enterrada. Sem uma política agressiva e mensurável de desvio de aterro, o município despende dezenas de milhões de reais anualmente apenas para soterrar resíduos com potencial econômico de reciclagem ou compostagem. A ausência de um Data Warehouse unificado impede a apuração do **custo real de destinação por habitante e por bairro**.

### 2.2 Subutilização de Cooperativas e Ínfima Coleta Seletiva
Apesar do marco legal estabelecido pela Política Nacional de Resíduos Sólidos (Lei Federal nº 12.305/2010), a taxa de reciclagem em grandes capitais do Nordeste permanece abaixo de 3% a 4%. As cooperativas de catadores credenciadas operam abaixo de sua capacidade nominal de triagem devido à falta de logística reversa estruturada e à escassez de dados para guiar a expansão de Pontos de Entrega Voluntária (PEVs) e Ecopontos nos bairros com maior propensão de descarte reciclável seco (papel, plástico, metal e vidro).

### 2.3 Proliferação de Pontos Viciados de Descarte Clandestino
Em diversas comunidades e vias secundárias, a ausência de infraestrutura próxima e a ação predatória de descartadores ilegais de entulho da construção civil (Resíduos da Construção e Demolição — RCD) criam os chamados **"pontos viciados" de lixo**. Esse passivo ambiental acarreta graves consequências sistêmicas:
* **Entupimento de Macro e Microdrenagem Pluvial:** Durante os períodos de chuvas torrenciais (abril a julho), o lixo carreado obstrui bueiros e canais, deflagrando alagamentos crônicos.
* **Sobrecarga de Encostas:** O acúmulo de entulho irregular em encostas satura o solo, aumentando o risco geológico de deslizamentos de terra.
* **Saúde Pública:** Formação de focos vetores de arboviroses (Dengue, Zika, Chikungunya) e leptospirose.
* **Custo de Zeladoria Emergencial:** A remoção de lixo clandestino demanda maquinário pesado extraordinário (retroescavadeiras e caminhões basculantes), custando até 3 vezes mais que a coleta regular domiciliar.

### 2.4 Ineficiência Logística e Pegada de Carbono da Frota
A frota de caminhões compactadores e caçambas opera muitas vezes em rotas históricas pré-fixadas, desprovidas de telemetria e balanceamento dinâmico. Caminhões retornam às centrais de pesagem com carga incompleta ou realizam trajetos ociosos, elevando o consumo de óleo diesel e aumentando as emissões fugitivas de dióxido de carbono ($CO_2$) e material particulado na atmosfera urbana.

---

## 3. Justificativa e Alinhamento com a Agenda 2030 da ONU (ODS)

O projeto EcoCidade posiciona a tecnologia de banco de dados como instrumento de transformação socioambiental, alinhando-se diretamente aos **Objetivos de Desenvolvimento Sustentável (ODS)** estabelecidos pela ONU:

![ODS da ONU](../materiais/ods_onu.jpeg)

### 3.1 ODS 11: Cidades e Comunidades Sustentáveis (Foco Primário)
O núcleo do projeto atende diretamente à **Meta 11.6**:
> *"Até 2030, reduzir o impacto ambiental negativo per capita das cidades, inclusive prestando especial atenção à qualidade do ar, gestão de resíduos municipais e outros."*

A construção de um repositório analítico permite acompanhar a evolução da geração per capita de resíduos em cada distrito, mensurar o índice de cobertura dos serviços de limpeza pública e identificar disparidades socioespaciais de infraestrutura. Adicionalmente, apoia a **Meta 11.a** ao fornecer subsídios quantitativos para o planejamento territorial integrado e sustentável da prefeitura.

### 3.2 ODS 12: Consumo e Produção Responsáveis (Conexão Secundária)
O projeto endereça a **Meta 12.5**:
> *"Até 2030, reduzir substancialmente a geração de resíduos por meio da prevenção, redução, reciclagem e reuso."*

Através da modelagem dimensional de rotas seletivas e pontos de entrega de recicláveis, o sistema rastreia o volume em toneladas destinado a centros de triagem e compostagem, fomentando o conceito de **Economia Circular** em substituição ao modelo linear extrativo ("extrair, consumir e aterrar").

### 3.3 ODS 13: Ação Contra a Mudança Global do Clima (Conexão Secundária)
Alinhado à **Meta 13.2** (integração de medidas climáticas nas políticas municipais):
* O desvio de resíduos orgânicos de aterros sanitários evita a decomposição anaeróbica que gera gás metano ($CH_4$), um gás de efeito estufa 28 vezes mais potente que o $CO_2$ em um horizonte de 100 anos.
* A otimização logística das rotas de coleta viabilizada pelo DW reduz o consumo de diesel da frota pesada, diminuindo as emissões diretas de carbono.

### 3.4 ODS 8: Trabalho Decente e Crescimento Econômico (Impacto Social)
Ao integrar cooperativas de catadores credenciadas no modelo de dados como agentes centrais de destinação, o sistema apoia a inclusão produtiva e a geração de renda formalizada para populações historicamente vulnerabilizadas.

---

## 4. Engenharia de Requisitos do Sistema de Dados

Para garantir robustez técnica e aderência estrita às boas práticas de engenharia de software e banco de dados, os requisitos do projeto foram mapeados em três categorias:

### 4.1 Requisitos de Negócio (RN)
* **RN01 — Rastreamento de Balança e Pesagem Líquida:** O sistema deve registrar com precisão o peso bruto, a tara do veículo e o peso líquido (em kg e toneladas) em todas as entradas de resíduos nas instalações de destinação.
* **RN02 — Gestão e SLA de Denúncias Clandestinas:** As solicitações de remoção de lixo e entulho irregular (canal 156) devem ser categorizadas por severidade, registrando o tempo decorrido até a ordem de serviço de remoção (SLA de resposta).
* **RN03 — Rastreabilidade da Cadeia de Reciclagem:** O sistema deve discriminar os volumes entregues a cooperativas credenciadas por tipologia de material (papel/papelão, plástico, metal, vidro e eletrônicos).
* **RN04 — Custo Parametrizado por Destino:** O sistema deve computar as despesas operacionais públicas com base nos contratos por tonelada destinados a aterros privados versus os custos de logística para cooperativas e usinas.

### 4.2 Requisitos Funcionais (RF)
* **RF01 — Modelagem Transacional Normalizada (OLTP):** Disponibilizar no mínimo 6 tabelas relacionais em 3ª Forma Normal (3NF) integrando bairros, pontos de coleta, veículos da frota, rotas, pesagens, cooperativas, destinos e ocorrências.
* **RF02 — Pipeline de Extração, Transformação e Carga (ETL):** Implementar rotinas SQL idempotentes para carregar o Data Warehouse, garantindo geração de Surrogate Keys (`sk_`), conformidade de dimensões e tratamento de nulos/datas.
* **RF03 — Mineração de Dados (AED):** Aplicar o método de clusterização **K-Means** sobre os bairros para identificar agrupamentos operacionais homogêneos (ex.: bairros críticos de entulho vs. bairros potenciais de coleta seletiva).
* **RF04 — Consultas Analíticas Piramidais:** Fornecer 15 consultas SQL otimizadas divididas igualmente entre os níveis Operacional (5), Tático (5) e Estratégico (5).
* **RF05 — Formulação de Plano de Ação 5W2H:** Estruturar um plano executivo de tarefas e metas corporativas baseado nas conclusões geradas pelas consultas e pela mineração de dados.

### 4.3 Requisitos Não-Funcionais (RNF)
* **RNF01 — Ecossistema Open-Source:** Todas as tecnologias utilizadas devem ser de código aberto e gratuitas (MySQL 8.0 Community, Python 3, Metabase Open-Source e Docker CE).
* **RNF02 — Integridade Referencial Estrita:** O banco OLTP deve aplicar chaves primárias (`PRIMARY KEY`), chaves estrangeiras (`FOREIGN KEY`) com ações referenciais consistentes e restrições de domínio (`CHECK`/`ENUM`).
* **RNF03 — Otimização Analítica (Star Schema):** O Data Warehouse deve adotar modelo dimensional com separação explícita de grão, tabelas de fatos puras e tabelas de dimensões indexadas.
* **RNF04 — Reprodutibilidade Zero-Touch:** O ambiente completo deve ser inicializável com um único comando (`docker compose up -d`), com scripts DDL, DML e ETL executados de forma sequencial e automática.

---

## 5. Metodologia PBL Aplicada (Cordeiro et al., 2018)

O projeto segue a estrutura pedagógica de **Problem-Based Learning (PBL)** documentada no artigo científico dos autores:

> **Referência:**  
> Martins, V. F., Sampaio, P. N. M., Cordeiro, A. J. A., & Viana, B. F. (2018).  
> *Implementing a Data Network Infrastructure Course using a Problem-based Learning Methodology*.  
> **Journal of Information Systems Engineering & Management**, 3(2), 10. DOI: [10.20897/jisem.201810](https://doi.org/10.20897/jisem.201810)

![As 8 Etapas do Método PBL](../materiais/fluxo_pbl_artigo.png)

A operacionalização prática do fluxo ocorre da seguinte forma:

```
[Etapa I: Análise do Problema] ──> Diagnóstico das dores municipais de resíduos e ODS 11
            │
[Etapa II: Levantamento de Hipóteses] ──> Hipóteses: rotas fixas e falta de PEVs geram custos e entulho
            │
[Etapa III: Tentativas com Conhecimento Disponível] ──> Modelagem conceitual preliminar de dados
            │
[Etapa IV: Pontos de Aprendizagem] ──> Aprofundamento em Star Schema, ETL robusto e K-Means
            │
[Etapa V: Planejamento em Grupo] ──> Sprints no PLANEJAMENTO.md e cards no Notion Calendar
            │
[Etapa VI: Aplicação dos Conhecimentos] ──> Construção do OLTP, scripts SQL, DW e consultas
            │
[Etapa VII: Produção de Documentação] ──> Dicionário de dados, contextualização e 5W2H
            │
[Etapa VIII: Avaliação do Processo] ──> Feedback parcial (19/10) e apresentação perante banca (06/11)
```

---

## 6. Conclusão e Próximos Passos

A contextualização aqui formalizada estabelece a base teórica, metodológica e funcional necessária para atingir a nota máxima no **Item 1 do Barema (1,0 ponto)**. 

Com o cenário de negócio, os requisitos e os vínculos com a ODS 11 consolidados, o projeto avança diretamente para a concepção e implementação técnica do **Item 2 (Modelagem OLTP — 8 Entidades)** e **Item 5 (Scripts DDL e Carga)**.
