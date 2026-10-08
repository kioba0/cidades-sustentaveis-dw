# Infraestrutura Local & Orquestração Docker (Zero-Touch)

> **Projeto:** EcoCidade — Gestão de Resíduos & Cidades Sustentáveis  
> **Serviços:** MySQL 8.0 Community & Metabase Open-Source

---

## 🚀 Como Inicializar o Ambiente

Para subir a infraestrutura completa com ambos os bancos (`ecocidade_oltp` e `dw_ecocidade`) **100% criados e populados**:

```bash
cd docker/
docker compose up -d
```

### Ordem de Execução Automática (`docker/init/`):
1. `01_oltp_schema.sql`: DDL das 8 tabelas transacionais do OLTP.
2. `02_oltp_seed.sql`: Carga com 16 bairros de Salvador, rotas, veículos, cooperativas, 1.624 pesagens e 250 chamados.
3. `03_dw_schema.sql`: DDL das 6 dimensões conformadas e 2 tabelas de fatos do DW.
4. `04_etl_pipeline.sql`: Pipeline de ETL que extrai, transforma e carrega o DW.

---

## 🔑 Credenciais e Portas de Acesso

| Serviço | URL / Host | Porta | Usuário / Login | Senha |
|---|---|:---:|---|---|
| **MySQL 8.0** | `localhost` | `3306` | `root` | `root` |
| **Metabase BI** | `http://localhost:3000` | `3000` | *(configuração inicial na interface)* | - |

---

## 🔍 Como Validar os Dados via Linha de Comando:

```bash
# Validar contagem no ambiente transacional OLTP
docker exec -i ecocidade_mysql mysql -uroot -proot -e "USE ecocidade_oltp; SHOW TABLES;"

# Validar contagem no Data Warehouse OLAP
docker exec -i ecocidade_mysql mysql -uroot -proot -e "
USE dw_ecocidade;
SELECT 'dim_tempo' AS tabela, COUNT(*) AS total FROM dim_tempo
UNION ALL SELECT 'dim_bairro', COUNT(*) FROM dim_bairro
UNION ALL SELECT 'fato_coleta_residuos', COUNT(*) FROM fato_coleta_residuos
UNION ALL SELECT 'fato_ocorrencias_descarte', COUNT(*) FROM fato_ocorrencias_descarte;
"
```
