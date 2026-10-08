# Item 4 — Dicionário de Dados Exaustivo (OLTP e OLAP)

> **Disciplina:** Tópicos Especiais em Banco de Dados  
> **Instituição:** Universidade do Estado da Bahia (UNEB)  
> **Docente:** Prof. Me. Antônio José A. Cordeiro  
> **Projeto:** EcoCidade — Laboratório de Dados para Cidades Sustentáveis  
> **Entregável:** Item 4 do Barema Oficial (Nota Máxima: 1,0 ponto)  
> **Schemas Documentados:** `ecocidade_oltp` (Transacional) e `dw_ecocidade` (Analítico)

---

## 1. Convenções e Notações Adotadas

| Sigla | Significado Técnico | Descrição |
|:---:|---|---|
| **PK** | *Primary Key* | Chave Primária — Identificador exclusivo e imutável da tupla. |
| **FK** | *Foreign Key* | Chave Estrangeira — Garante integridade referencial com tabela pai. |
| **UQ** | *Unique Constraint* | Restrição de Unicidade — Garante que valores não se repitam. |
| **NK** | *Natural Key* | Chave Natural de Negócio — Identificador originário do sistema legado/OLTP. |
| **SK** | *Surrogate Key* | Chave Substituta — Inteiro sequencial gerado artificialmente para o DW. |
| **DD** | *Degenerate Dimension* | Dimensão Degenerada — Identificador operacional mantido na tabela de fatos. |
| **CHK** | *Check Constraint* | Restrição condicional de domínio validada pelo SGBD. |

---

## PARTE 1: AMBIENTE OPERACIONAL TRANSACIONAL (`ecocidade_oltp`)

### 1.1 Tabela `bairros`
> **Finalidade:** Armazena os distritos urbanos e Prefeituras-Bairro de Salvador/BA para segmentação socioespacial.

| Atributo | Tipo de Dado | Nulo? | Chave | Regra / Restrição | Descrição Semântica de Negócio |
|---|---|:---:|:---:|---|---|
| `id_bairro` | `INT` | Não | **PK** | `AUTO_INCREMENT` | Identificador único do bairro. |
| `nome_bairro` | `VARCHAR(100)` | Não | **UQ** | Nome oficial | Denominação oficial do bairro (ex: 'Pituba', 'Cajazeiras X'). |
| `regiao_administrativa`| `VARCHAR(80)` | Não | Índice | Prefeitura-Bairro | Divisão administrativa municipal de Salvador. |
| `populacao_estimada` | `INT` | Não | - | `CHECK (> 0)` | Número estimado de habitantes (Censo/IBGE). |
| `area_km2` | `DECIMAL(6,2)` | Não | - | `CHECK (> 0)` | Extensão territorial em quilômetros quadrados. |
| `renda_media_domiciliar`| `DECIMAL(10,2)`| Sim | - | Em Reais (R$) | Renda média mensal familiar do distrito. |
| `data_cadastro` | `DATETIME` | Não | - | `DEFAULT CURRENT_TIMESTAMP` | Data e hora de inserção do registro. |

---

### 1.2 Tabela `destinos_finais`
> **Finalidade:** Cadastro das instalações autorizadas receptoras de resíduos (aterros, centros de triagem e usinas).

| Atributo | Tipo de Dado | Nulo? | Chave | Regra / Restrição | Descrição Semântica de Negócio |
|---|---|:---:|:---:|---|---|
| `id_destino` | `INT` | Não | **PK** | `AUTO_INCREMENT` | Identificador único da instalação de destinação. |
| `nome_instalacao` | `VARCHAR(120)` | Não | **UQ** | Razão/Nome | Nome fantasia ou oficial do centro receptor. |
| `tipo_instalacao` | `ENUM` | Não | Índice | 4 opções | 'Aterro Sanitario Metropolitano', 'Centro de Triagem Cooperativa', 'Usina de Compostagem', 'Ecoponto de Transbordo'. |
| `bairro_localizacao` | `VARCHAR(100)` | Não | - | Nome bairro | Bairro ou município metropolitano onde está instalada. |
| `custo_tonelada_reais` | `DECIMAL(8,2)` | Não | - | Em Reais (R$) | Custo por tonelada pago pelo erário público na destinação. |
| `capacidade_maxima_ton_mes`| `DECIMAL(10,2)`| Não | - | `CHECK (> 0)` | Teto operacional mensal suportado pela planta. |
| `licenca_ambiental` | `VARCHAR(50)` | Não | **UQ** | Registro INEMA | Número da licença ambiental de operação ativa. |
| `status` | `ENUM` | Não | - | `DEFAULT 'Operacional'` | 'Operacional', 'Em Reforma', 'Interditado'. |

---

### 1.3 Tabela `cooperativas_reciclagem`
> **Finalidade:** Entidades associativas e cooperativas de catadores credenciadas para fomento da economia circular.

| Atributo | Tipo de Dado | Nulo? | Chave | Regra / Restrição | Descrição Semântica de Negócio |
|---|---|:---:|:---:|---|---|
| `id_cooperativa` | `INT` | Não | **PK** | `AUTO_INCREMENT` | Identificador único da cooperativa. |
| `id_bairro` | `INT` | Não | **FK** | `→ bairros.id_bairro` | Bairro sede onde funciona o galpão de triagem. |
| `nome_cooperativa` | `VARCHAR(150)` | Não | **UQ** | Razão Social | Nome registrado da associação de catadores. |
| `cnpj` | `VARCHAR(18)` | Não | **UQ** | Formato CNPJ | Cadastro Nacional de Pessoa Jurídica. |
| `capacidade_triagem_ton_dia`| `DECIMAL(5,2)` | Não | - | `CHECK (> 0)` | Volume diário que os associados conseguem processar. |
| `qtd_catadores_associados` | `INT` | Não | - | `CHECK (> 0)` | Número de famílias/trabalhadores cooperados. |
| `materiais_aceitos` | `VARCHAR(200)` | Não | - | Lista texto | Materiais segregados (Plásticos, Papelão, Vidro, Metais). |
| `data_convenio` | `DATE` | Não | - | Data formal | Data de início do convênio municipal de apoio. |

---

### 1.4 Tabela `pontos_coleta`
> **Finalidade:** Infraestrutura de entrega voluntária de recicláveis e monitoramento de lixões clandestinos.

| Atributo | Tipo de Dado | Nulo? | Chave | Regra / Restrição | Descrição Semântica de Negócio |
|---|---|:---:|:---:|---|---|
| `id_ponto` | `INT` | Não | **PK** | `AUTO_INCREMENT` | Identificador único do ponto de coleta. |
| `id_bairro` | `INT` | Não | **FK** | `→ bairros.id_bairro` | Bairro onde o ponto está fisicamente instalado/mapeado. |
| `nome_identificador` | `VARCHAR(120)` | Não | - | Descrição local | Nome identificador (ex: 'PEV Orla Jardim de Alah'). |
| `tipo_ponto` | `ENUM` | Não | Índice | 4 opções | 'Ecoponto Central', 'PEV Reciclaveis', 'Lixeira Subterranea', 'Ponto Viciado Clandestino'. |
| `logradouro` | `VARCHAR(200)` | Não | - | Endereço | Rua, avenida, praça ou ponto de referência geográfico. |
| `capacidade_m3` | `DECIMAL(6,2)` | Não | - | `CHECK (>= 0)` | Volume volumétrico das caçambas ou lixeiras instaladas. |
| `data_instalacao` | `DATE` | Não | - | Data ativação | Data em que foi instalado ou identificado pela fiscalização. |
| `status_operacional` | `ENUM` | Não | - | `DEFAULT 'Ativo'` | 'Ativo', 'Interditado', 'Em Manutencao', 'Eliminado'. |

---

### 1.5 Tabela `veiculos_frota`
> **Finalidade:** Registro de veículos e caminhões compactadores da frota de limpeza urbana municipal.

| Atributo | Tipo de Dado | Nulo? | Chave | Regra / Restrição | Descrição Semântica de Negócio |
|---|---|:---:|:---:|---|---|
| `id_veiculo` | `INT` | Não | **PK** | `AUTO_INCREMENT` | Identificador único do veículo. |
| `placa` | `VARCHAR(10)` | Não | **UQ** | Padrão Mercosul | Placa oficial de emplacamento do veículo. |
| `modelo` | `VARCHAR(80)` | Não | - | Modelo chassi | Fabricante e chassi (ex: 'Mercedes-Benz Atego 1729'). |
| `tipo_veiculo` | `ENUM` | Não | Índice | 4 opções | 'Compactador Pesado', 'Caminhao Cacamba', 'Poliguindaste', 'Veiculo Utilitario Leve'. |
| `capacidade_carga_ton` | `DECIMAL(5,2)` | Não | - | `CHECK (> 0)` | Capacidade nominal de carga útil em toneladas. |
| `empresa_operadora` | `VARCHAR(100)` | Não | - | Nome consórcio | Órgão ou consórcio prestador (ex: 'Limpurb', 'Consórcio Salvador Limpa'). |
| `emissao_co2_km_g` | `DECIMAL(6,2)` | Não | - | `CHECK (>= 0)` | Fator de emissão de CO₂ estimado por km (gramas/km). |
| `ano_fabricacao` | `YEAR` | Não | - | Ano | Ano de fabricação do veículo. |
| `status` | `ENUM` | Não | Índice | `DEFAULT 'Operacional'` | 'Operacional', 'Em Manutencao', 'Inativo'. |

---

### 1.6 Tabela `rotas_coleta`
> **Finalidade:** Itinerários pré-definidos de coleta domiciliar, seletiva e comercial.

| Atributo | Tipo de Dado | Nulo? | Chave | Regra / Restrição | Descrição Semântica de Negócio |
|---|---|:---:|:---:|---|---|
| `id_rota` | `INT` | Não | **PK** | `AUTO_INCREMENT` | Identificador único da rota. |
| `codigo_rota` | `VARCHAR(20)` | Não | **UQ** | Sigla de serviço | Código da rota (ex: 'ROT-DOM-01', 'ROT-SEL-04'). |
| `id_bairro_origem` | `INT` | Não | **FK** | `→ bairros.id_bairro` | Bairro de início do recolhimento. |
| `id_bairro_destino` | `INT` | Não | **FK** | `→ bairros.id_bairro` | Bairro final do trecho percorrido. |
| `turno` | `ENUM` | Não | Índice | 3 opções | 'Matutino', 'Vespertino', 'Noturno'. |
| `tipo_coleta` | `ENUM` | Não | Índice | 4 opções | 'Domiciliar Convencional', 'Seletiva Reciclavel', 'Entulho e Volumosos', 'Hospitalar'. |
| `frequencia_semanal` | `INT` | Não | - | `CHECK (1 a 7)` | Quantidade de dias por semana em que a rota opera. |
| `extensao_estimada_km`| `DECIMAL(6,2)` | Não | - | `CHECK (> 0)` | Extensão média do trajeto percorrido em km. |

---

### 1.7 Tabela `pesagens_coleta`
> **Finalidade:** Transações da balança rodoviária no momento da descarga dos caminhões coletores.

| Atributo | Tipo de Dado | Nulo? | Chave | Regra / Restrição | Descrição Semântica de Negócio |
|---|---|:---:|:---:|---|---|
| `id_pesagem` | `BIGINT` | Não | **PK** | `AUTO_INCREMENT` | Código sequencial da pesagem na balança. |
| `id_veiculo` | `INT` | Não | **FK** | `→ veiculos_frota.id_veiculo`| Caminhão que descarregou o resíduo. |
| `id_rota` | `INT` | Não | **FK** | `→ rotas_coleta.id_rota` | Rota executada antes do descarregamento. |
| `id_destino` | `INT` | Não | **FK** | `→ destinos_finais.id_destino`| Instalação onde foi depositado (aterro ou usina). |
| `data_hora_pesagem` | `DATETIME` | Não | Índice | Timestamp balança | Momento exato da aferição pelo operador. |
| `peso_bruto_kg` | `DECIMAL(9,2)` | Não | - | `CHECK (> 0)` | Peso total do caminhão carregado na entrada. |
| `tara_kg` | `DECIMAL(9,2)` | Não | - | `CHECK (> 0)` | Peso do caminhão vazio após descarregar na saída. |
| `peso_liquido_kg` | `DECIMAL(9,2)` | Não | - | `STORED COMPUTED` | Cálculo automático: `peso_bruto_kg - tara_kg`. |
| `tipo_residuo` | `ENUM` | Não | Índice | 5 opções | 'Organico Domiciliar', 'Reciclavel Seco', 'Entulho RCD', 'Poda e Jardinagem', 'Rejeito Inerte'. |
| `km_odometro` | `DECIMAL(9,2)` | Não | - | Hodômetro | Quilometragem registrada no painel do caminhão. |
| `tempo_descarregamento_minutos`| `INT` | Não | - | `CHECK (>= 0)` | Duração da manobra de descarga na instalação. |

---

### 1.8 Tabela `chamados_descarte_irregular`
> **Finalidade:** Denúncias cidadãs do canal Fala Salvador 156 sobre descarte clandestino e entulho em vias públicas.

| Atributo | Tipo de Dado | Nulo? | Chave | Regra / Restrição | Descrição Semântica de Negócio |
|---|---|:---:|:---:|---|---|
| `id_chamado` | `BIGINT` | Não | **PK** | `AUTO_INCREMENT` | Identificador único do chamado. |
| `protocolo_cidadao` | `VARCHAR(30)` | Não | **UQ** | Protocolo 156 | Código de acompanhamento fornecido ao munícipe. |
| `id_bairro` | `INT` | Não | **FK** | `→ bairros.id_bairro` | Bairro onde o descarte irregular está ocorrendo. |
| `id_ponto_coleta` | `INT` | Sim | **FK** | `→ pontos_coleta.id_ponto`| Se associado a ponto viciado monitorado (opcional). |
| `data_abertura` | `DATETIME` | Não | Índice | Registro cidadão | Data e hora em que a denúncia foi aberta. |
| `data_atendimento` | `DATETIME` | Sim | - | Conclusão OS | Data e hora em que a equipe concluiu a remoção. |
| `descricao_ocorrencia`| `TEXT` | Não | - | Descrição livre | Detalhes do material abandonado em via pública. |
| `volume_estimado_m3` | `DECIMAL(6,2)` | Não | - | `CHECK (> 0)` | Volume aproximado de entulho relatado pelo fiscal. |
| `severidade_risco` | `ENUM` | Não | Índice | 3 opções | 'Baixo', 'Medio', 'Critico / Risco Encosta ou Alagamento'. |
| `status` | `ENUM` | Não | Índice | `DEFAULT 'Aberto'` | 'Aberto', 'Em Andamento', 'Concluido', 'Cancelado'. |
| `id_veiculo_atendimento`| `INT` | Sim | **FK** | `→ veiculos_frota.id_veiculo`| Caminhão caçamba que realizou a remoção. |

---

## PARTE 2: AMBIENTE MULTIDIMENSIONAL OLAP (`dw_ecocidade`)

### 2.1 Dimensão `dim_tempo`
> **Finalidade:** Eixo cronológico para agregação temporal e inteligência de negócios.

| Atributo | Tipo de Dado | Nulo? | Chave | Origem / Regra | Descrição Semântica |
|---|---|:---:|:---:|---|---|
| `sk_tempo` | `INT` | Não | **PK** | Formato YYYYMMDD | Surrogate Key temporal compacta (ex: 20261008). |
| `data_completa` | `DATE` | Não | **UQ** | Data calendário | Data padrão no formato ISO 8601 (YYYY-MM-DD). |
| `ano` | `SMALLINT` | Não | - | `YEAR(data)` | Ano civil (ex: 2026). |
| `mes` | `TINYINT` | Não | - | `MONTH(data)` | Mês numérico (1 a 12). |
| `nome_mes` | `VARCHAR(20)` | Não | - | Nome português | 'Janeiro', 'Fevereiro', ..., 'Dezembro'. |
| `dia` | `TINYINT` | Não | - | `DAY(data)` | Dia do mês (1 a 31). |
| `dia_semana` | `TINYINT` | Não | - | `DAYOFWEEK(data)` | Dia da semana (1 = Domingo, 7 = Sábado). |
| `nome_dia_semana` | `VARCHAR(20)` | Não | - | Nome português | 'Segunda-feira', 'Terça-feira', etc. |
| `trimestre` | `TINYINT` | Não | - | `QUARTER(data)` | Trimestre do ano (1 a 4). |
| `semestre` | `TINYINT` | Não | - | 1 ou 2 | Semestre civil do ano. |
| `eh_fim_semana` | `BOOLEAN` | Não | - | 0 ou 1 | Flag indicando se é sábado ou domingo. |

---

### 2.2 Dimensão `dim_bairro`
> **Finalidade:** Visão geográfica enriquecida com indicadores demográficos e Prefeituras-Bairro.

| Atributo | Tipo de Dado | Nulo? | Chave | Origem / Regra | Descrição Semântica |
|---|---|:---:|:---:|---|---|
| `sk_bairro` | `INT` | Não | **PK** | `AUTO_INCREMENT` | Surrogate Key da dimensão bairro. |
| `id_bairro_origem` | `INT` | Não | **NK/UQ**| `bairros.id_bairro` | Chave Natural da tabela transacional. |
| `nome_bairro` | `VARCHAR(100)` | Não | - | `bairros.nome_bairro` | Nome oficial do bairro de Salvador. |
| `regiao_administrativa`| `VARCHAR(80)` | Não | Índice | `bairros.regiao_adm` | Prefeitura-Bairro responsável. |
| `faixa_populacional` | `VARCHAR(40)` | Não | - | Derivado população | 'Até 20k hab', '20k a 50k hab', 'Mais de 50k hab'. |
| `densidade_demografica`| `VARCHAR(30)` | Não | - | População / Área | 'Baixa', 'Média', 'Alta', 'Muito Alta'. |
| `classe_renda` | `VARCHAR(30)` | Não | - | Derivado renda | 'Vulnerabilidade Alta', 'Média Baixa', 'Média Alta', 'Alta'. |

---

### 2.3 Dimensão `dim_tipo_residuo`
> **Finalidade:** Caracterização dos fluxos de materiais, potencial reciclável e parâmetros de GEE.

| Atributo | Tipo de Dado | Nulo? | Chave | Origem / Regra | Descrição Semântica |
|---|---|:---:|:---:|---|---|
| `sk_tipo_residuo` | `INT` | Não | **PK** | `AUTO_INCREMENT` | Surrogate Key da tipologia do resíduo. |
| `tipo_residuo_origem` | `VARCHAR(50)` | Não | **NK/UQ**| ENUM transacional | 'Organico Domiciliar', 'Reciclavel Seco', etc. |
| `categoria_macro` | `VARCHAR(40)` | Não | Índice | Agrupamento | 'Domiciliar', 'Reciclável Seco', 'Entulho RCD', 'Orgânico'. |
| `potencial_reciclagem_pct`|`DECIMAL(5,2)`| Não | - | % Teórico | Aproveitamento potencial para economia circular. |
| `fator_emissao_ch4` | `DECIMAL(6,3)` | Não | - | Fator IPCC | Emissão de metano evitada ao não ser aterrado. |

---

### 2.4 Dimensão `dim_veiculo`
> **Finalidade:** Capacidade operacional e perfil da frota veicular da limpeza pública.

| Atributo | Tipo de Dado | Nulo? | Chave | Origem / Regra | Descrição Semântica |
|---|---|:---:|:---:|---|---|
| `sk_veiculo` | `INT` | Não | **PK** | `AUTO_INCREMENT` | Surrogate Key do caminhão/veículo. |
| `id_veiculo_origem` | `INT` | Não | **NK/UQ**| `veiculos.id_veiculo`| Chave Natural do veículo no OLTP. |
| `placa` | `VARCHAR(10)` | Não | - | `veiculos.placa` | Placa oficial do veículo. |
| `modelo` | `VARCHAR(80)` | Não | - | `veiculos.modelo` | Modelo comercial e fabricante do chassi. |
| `tipo_veiculo` | `VARCHAR(40)` | Não | Índice | `veiculos.tipo` | Compactador Pesado, Caçamba, Poliguindaste, etc. |
| `empresa_operadora` | `VARCHAR(100)` | Não | - | Concessionária | Concessionária responsável pela operação. |
| `faixa_capacidade` | `VARCHAR(30)` | Não | - | Derivado carga | 'Pequeno Porte (<5t)', 'Médio Porte (5-10t)', 'Pesado (>10t)'. |

---

### 2.5 Dimensão `dim_destino`
> **Finalidade:** Identificação da instalação receptora e indicador de sustentabilidade urbana.

| Atributo | Tipo de Dado | Nulo? | Chave | Origem / Regra | Descrição Semântica |
|---|---|:---:|:---:|---|---|
| `sk_destino` | `INT` | Não | **PK** | `AUTO_INCREMENT` | Surrogate Key do destino. |
| `id_destino_origem` | `INT` | Não | **NK/UQ**| `destinos.id_destino`| Chave Natural da instalação receptora. |
| `nome_instalacao` | `VARCHAR(120)` | Não | - | Nome oficial | Razão social ou denominação da usina/aterro. |
| `tipo_instalacao` | `VARCHAR(60)` | Não | - | Categoria | Aterro Metropolitano, Centro de Triagem, Usina. |
| `bandeira_sustentavel`| `VARCHAR(50)` | Não | Índice | Flag ODS 11.6 | 'Sustentavel (Reciclagem)' vs 'Convencional (Aterro)'. |

---

### 2.6 Dimensão `dim_severidade`
> **Finalidade:** Escala de risco para denúncias de entulho clandestino e acúmulo em encostas.

| Atributo | Tipo de Dado | Nulo? | Chave | Origem / Regra | Descrição Semântica |
|---|---|:---:|:---:|---|---|
| `sk_severidade` | `INT` | Não | **PK** | `AUTO_INCREMENT` | Surrogate Key da severidade. |
| `nivel_severidade` | `VARCHAR(50)` | Não | **NK/UQ**| ENUM severidade | 'Baixo', 'Medio', 'Critico / Risco Encosta ou Alagamento'. |
| `impacto_risco_geologico`|`VARCHAR(10)`| Não | - | 'Sim' ou 'Nao' | Flag para priorização em épocas de chuvas fortes. |

---

### 2.7 Tabela Fato: `fato_coleta_residuos`
> **Grão:** Um registro individual de pesagem na balança executado por um caminhão ao final de uma rota.

| Atributo | Tipo de Dado | Nulo? | Chave | Tipo Métrica | Descrição e Fórmula de Cálculo |
|---|---|:---:|:---:|:---:|---|
| `sk_fato_coleta` | `BIGINT` | Não | **PK** | - | Surrogate Key exclusiva do fato. |
| `sk_tempo` | `INT` | Não | **FK** | - | Chave da data em que ocorreu a pesagem. |
| `sk_bairro` | `INT` | Não | **FK** | - | Chave do bairro atendido pela rota. |
| `sk_tipo_residuo` | `INT` | Não | **FK** | - | Chave do tipo de resíduo transportado. |
| `sk_veiculo` | `INT` | Não | **FK** | - | Chave do caminhão que realizou o transporte. |
| `sk_destino` | `INT` | Não | **FK** | - | Chave da instalação que recebeu o resíduo. |
| `codigo_rota_dd` | `VARCHAR(20)` | Não | **DD** | - | Dimensão Degenerada: Código da rota operacional. |
| `peso_liquido_ton` | `DECIMAL(8,3)` | Não | - | Totalmente Aditiva | Carga útil descarregada: `(peso_bruto - tara) / 1000`. |
| `custo_destinacao_reais`|`DECIMAL(10,2)`| Não | - | Totalmente Aditiva | Custo financeiro público: `peso_ton * custo_ton_destino`. |
| `tempo_descarregamento_minutos`|`INT` | Não | - | Totalmente Aditiva | Tempo em minutos despendido na manobra de descarga. |
| `distancia_km` | `DECIMAL(6,2)` | Não | - | Totalmente Aditiva | Quilometragem estimada percorrida no turno. |
| `emissoes_estimadas_co2_kg`|`DECIMAL(8,2)`| Não | - | Totalmente Aditiva | Emissão de carbono: `(distancia_km * emissao_g_km) / 1000`. |

---

### 2.8 Tabela Fato: `fato_ocorrencias_descarte`
> **Grão:** Um chamado registrado no Fala Salvador 156 denunciando lixo ou entulho clandestino em via pública.

| Atributo | Tipo de Dado | Nulo? | Chave | Tipo Métrica | Descrição e Fórmula de Cálculo |
|---|---|:---:|:---:|:---:|---|
| `sk_fato_ocorrencia` | `BIGINT` | Não | **PK** | - | Surrogate Key exclusiva do fato de descarte. |
| `sk_tempo_abertura` | `INT` | Não | **FK** | - | Data em que o munícipe registrou o chamado. |
| `sk_tempo_atendimento`| `INT` | Sim | **FK** | - | Data em que a prefeitura concluiu o recolhimento. |
| `sk_bairro` | `INT` | Não | **FK** | - | Bairro onde o lixo irregular foi descartado. |
| `sk_veiculo_atendimento`|`INT` | Sim | **FK** | - | Caminhão caçamba que realizou o atendimento. |
| `sk_severidade` | `INT` | Não | **FK** | - | Nível de risco da ocorrência (encosta, bueiro, via). |
| `protocolo_cidadao_dd`| `VARCHAR(30)` | Não | **DD** | - | Dimensão Degenerada: Protocolo 156 do cidadão. |
| `status_chamado_dd` | `VARCHAR(30)` | Não | **DD** | - | Dimensão Degenerada: Status atual ('Concluido', 'Aberto'). |
| `tempo_resolucao_horas`| `DECIMAL(6,1)`| Sim | - | Semi-Aditiva | SLA em horas decorridas: `TIMESTAMPDIFF(HOUR, abertura, atendimento)`. |
| `volume_estimado_m3` | `DECIMAL(6,2)` | Não | - | Totalmente Aditiva | Volume volumétrico de entulho recolhido. |
| `custo_remocao_reais` | `DECIMAL(10,2)`| Não | - | Totalmente Aditiva | Custo da operação emergencial de zeladoria. |

---

## 3. Matriz de Linhagem e Transformações do ETL (Data Lineage)

```
┌─────────────────────────────────┐           ┌───────────────────────────────────┐
│     Tabelas de Origem (OLTP)    │           │    Data Warehouse Destino (OLAP)  │
├─────────────────────────────────┤           ├───────────────────────────────────┤
│ bairros                         │ ────────> │ dim_bairro                        │
│ destinos_finais                 │ ────────> │ dim_destino                       │
│ veiculos_frota                  │ ────────> │ dim_veiculo                       │
│ pesagens_coleta.tipo_residuo    │ ────────> │ dim_tipo_residuo                  │
│ chamados.severidade_risco       │ ────────> │ dim_severidade                    │
│ Calendário / Datas de Pesagem   │ ────────> │ dim_tempo                         │
│                                 │           │                                   │
│ pesagens_coleta (Transações)    │ ────────> │ fato_coleta_residuos              │
│ chamados_descarte_irregular     │ ────────> │ fato_ocorrencias_descarte         │
└─────────────────────────────────┘           └───────────────────────────────────┘
```

Esta documentação fecha o mapeamento dos atributos, integridade, tipagem e rastreabilidade para o **Item 4 do Barema (1,0 ponto)**.
