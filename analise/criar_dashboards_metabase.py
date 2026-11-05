"""
Automação de Criação de Dashboards no Metabase BI
Projeto EcoCidade — Laboratório de Dados para Cidades Sustentáveis (PBL)
Disciplina: Tópicos Especiais em Banco de Dados — UNEB
Docente: Prof. Me. Antônio José A. Cordeiro

Objetivo:
- Conectar à API REST do Metabase (porta 3000)
- Mapear bancos de dados:
    * ecocidade_oltp (Ambiente Operacional)
    * dw_ecocidade   (Ambiente Dimensional OLAP)
- Criar 15 Questões (Cards) correspondentes a C1..C15
- Criar 3 Dashboards Integrados:
    1. EcoCidade — 1. Painel Operacional (Chão de Fábrica) [C1 a C5]
    2. EcoCidade — 2. Painel Tático (Frotas, Distritos & Cooperativas) [C6 a C10]
    3. EcoCidade — 3. Painel Estratégico (ODS 11, 12, 13 & Vida Útil do Aterro) [C11 a C15]
- Configurar layout responsivo (grid de 24 colunas) e salvar estado persistente.
"""

import os
import sys
import json
import urllib.request
import urllib.error

METABASE_URL = os.environ.get("METABASE_URL", "http://localhost:3000")
USERNAME = os.environ.get("METABASE_USER", "cerveja123@gmail.com")
PASSWORD = os.environ.get("METABASE_PASS", "cerveja123")


def make_request(endpoint, data=None, method=None, session_token=None):
    url = f"{METABASE_URL}{endpoint}"
    headers = {"Content-Type": "application/json"}
    if session_token:
        headers["X-Metabase-Session"] = session_token

    payload = json.dumps(data).encode("utf-8") if data is not None else None
    req = urllib.request.Request(url, data=payload, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req) as resp:
            content = resp.read().decode("utf-8")
            return json.loads(content) if content else {}
    except urllib.error.HTTPError as e:
        err_msg = e.read().decode("utf-8")
        print(f"❌ Erro HTTP {e.code} em {endpoint}: {err_msg}")
        raise


def authenticate():
    print(f"🔑 Autenticando no Metabase ({METABASE_URL}) com usuário {USERNAME}...")
    res = make_request("/api/session", {"username": USERNAME, "password": PASSWORD})
    token = res.get("id")
    if not token:
        raise RuntimeError("Falha na autenticação: token não retornado.")
    print("✅ Sessão autenticada com sucesso!")
    return token


def get_database_ids(token):
    print("🔍 Localizando bases de dados registradas no Metabase...")
    res = make_request("/api/database", session_token=token)
    databases = res.get("data", [])
    oltp_id = None
    dw_id = None

    for db in databases:
        dbname = db.get("details", {}).get("dbname", "")
        name = db.get("name", "")
        if "dw_ecocidade" in dbname or "dw_ecocidade" in name.lower() or "olap" in name.lower():
            dw_id = db["id"]
        elif "ecocidade_oltp" in dbname or "oltp" in name.lower() or "transacional" in name.lower():
            oltp_id = db["id"]

    print(f"   • Database OLTP (ecocidade_oltp): ID {oltp_id}")
    print(f"   • Database OLAP (dw_ecocidade):   ID {dw_id}")

    if not oltp_id or not dw_id:
        raise RuntimeError(f"Bases não encontradas! Encontrado OLTP: {oltp_id}, DW: {dw_id}")

    return oltp_id, dw_id


def clean_existing_ecocidade_dashboards(token):
    print("🧹 Verificando e arquivando dashboards antigos do EcoCidade...")
    dashboards = make_request("/api/dashboard", session_token=token)
    for d in dashboards:
        name = d.get("name", "")
        dash_id = d.get("id")
        if ("EcoCidade" in name or "Test Dash" in name or "Dash Teste" in name) and not d.get("archived"):
            print(f"   Arquivando dashboard pré-existente ID {dash_id} ('{name}')...")
            make_request(f"/api/dashboard/{dash_id}", {"archived": True}, method="PUT", session_token=token)


def get_existing_cards(token):
    cards = make_request("/api/card", session_token=token)
    card_map = {}
    for c in cards:
        if not c.get("archived"):
            card_map[c.get("name")] = c.get("id")
    return card_map


def create_or_get_card(name, sql_query, db_id, display_type, token, existing_cards, viz_settings=None):
    if viz_settings is None:
        viz_settings = {}

    card_payload = {
        "name": name,
        "dataset_query": {
            "type": "native",
            "native": {
                "query": sql_query.strip()
            },
            "database": db_id
        },
        "display": display_type,
        "visualization_settings": viz_settings
    }

    if name in existing_cards:
        card_id = existing_cards[name]
        try:
            make_request(f"/api/card/{card_id}", card_payload, method="PUT", session_token=token)
            print(f"   ♻️ Card atualizado: [{card_id}] {name} ({display_type})")
        except Exception as e:
            print(f"   ⚠️ Não foi possível atualizar card {card_id}: {e}")
        return card_id

    res = make_request("/api/card", card_payload, session_token=token)
    card_id = res.get("id")
    print(f"   ✅ Card criado: [{card_id}] {name} ({display_type})")
    return card_id


def create_dashboard(name, description, token):
    dash_payload = {
        "name": name,
        "description": description
    }
    res = make_request("/api/dashboard", dash_payload, session_token=token)
    dash_id = res.get("id")
    print(f"\n📊 Dashboard Criado: [{dash_id}] '{name}'")
    return dash_id


def add_cards_to_dashboard(dash_id, cards_layout, token):
    """
    cards_layout: lista de tuplas (card_id, row, col, size_x, size_y, viz_settings)
    No Metabase v0.48+ / v0.50+, para associar cards a um dashboard usa-se:
    PUT /api/dashboard/:id/cards com {"cards": [{"id": -idx, "card_id": card_id, ...}]}
    onde IDs negativos indicam novos dashcards a serem persistidos no grid.
    """
    cards_payload = []
    for idx, (card_id, row, col, size_x, size_y, viz) in enumerate(cards_layout, start=1):
        cards_payload.append({
            "id": -idx,
            "card_id": card_id,
            "row": row,
            "col": col,
            "size_x": size_x,
            "size_y": size_y,
            "series": [],
            "visualization_settings": viz or {},
            "parameter_mappings": []
        })

    # Atualiza posições e dimensões no grid do dashboard
    make_request(f"/api/dashboard/{dash_id}/cards", {"cards": cards_payload}, method="PUT", session_token=token)
    print(f"   📐 Layout posicionado com sucesso no Dashboard {dash_id} ({len(cards_layout)} cards)!")


def main():
    token = authenticate()
    oltp_id, dw_id = get_database_ids(token)
    clean_existing_ecocidade_dashboards(token)
    existing_cards = get_existing_cards(token)

    # =========================================================================
    # DEFINIÇÃO DOS CARDS E QUERIES
    # =========================================================================

    # --- SCORECARDS OPERACIONAIS (OLTP - PULSO DE 5 SEGUNDOS) ---
    q_kpi_o1 = "SELECT COUNT(*) AS caminhoes_ativos FROM veiculos_frota WHERE status = 'Operacional';"
    q_kpi_o2 = "SELECT ROUND(AVG(tempo_descarregamento_minutos), 1) AS tempo_medio_balanca_min FROM pesagens_coleta;"
    q_kpi_o3 = "SELECT COUNT(*) AS chamados_encostas_criticos FROM chamados_descarte_irregular WHERE severidade_risco = 'Critico / Risco Encosta ou Alagamento' AND status IN ('Aberto', 'Em Andamento');"
    q_kpi_o4 = """
SELECT COUNT(*) AS ecopontos_em_alerta
FROM (
    SELECT pc.id_ponto, pc.capacidade_m3, COALESCE(SUM(c.volume_estimado_m3), 0) AS vol
    FROM pontos_coleta pc
    LEFT JOIN chamados_descarte_irregular c
        ON (
            c.id_ponto_coleta = pc.id_ponto
            OR (
                c.id_ponto_coleta IS NULL 
                AND c.id_bairro = pc.id_bairro
                AND pc.id_ponto = (
                    SELECT MIN(pc_sub.id_ponto) 
                    FROM pontos_coleta pc_sub 
                    WHERE pc_sub.id_bairro = pc.id_bairro 
                      AND pc_sub.status_operacional = 'Ativo'
                )
            )
        )
        AND c.status IN ('Aberto', 'Em Andamento')
    WHERE pc.status_operacional = 'Ativo'
    GROUP BY pc.id_ponto, pc.capacidade_m3
    HAVING vol >= (pc.capacidade_m3 * 0.70)
) sub;
"""

    # --- SCORECARDS TÁTICOS (OLAP - DW) ---
    q_kpi_t1 = "SELECT ROUND(SUM(custo_destinacao_reais) / SUM(peso_liquido_ton), 2) AS custo_medio_por_ton_reais FROM fato_coleta_residuos;"
    q_kpi_t2 = """
SELECT ROUND(SUM(f.peso_liquido_ton * 95.50) - SUM(f.custo_destinacao_reais), 2) AS economia_liquida_cooperativas_reais
FROM fato_coleta_residuos f
INNER JOIN dim_destino d ON f.sk_destino = d.sk_destino
WHERE d.tipo_instalacao = 'Centro de Triagem Cooperativa';
"""
    q_kpi_t3 = """
SELECT ROUND(AVG(fo.tempo_resolucao_horas), 1) AS sla_medio_cluster_critico_horas
FROM fato_ocorrencias_descarte fo
INNER JOIN dim_bairro b ON fo.sk_bairro = b.sk_bairro
WHERE b.regiao_administrativa IN ('Liberdade/Sao Caetano', 'Suburbio Ferroviario');
"""

    # --- SCORECARDS ESTRATÉGICOS (OLAP - DW) ---
    q_kpi_e1 = """
SELECT ROUND((SUM(CASE WHEN d.bandeira_sustentavel != 'Convencional (Aterro)' THEN f.peso_liquido_ton ELSE 0 END) / SUM(f.peso_liquido_ton)) * 100, 1) AS taxa_desvio_atual_pct
FROM fato_coleta_residuos f
INNER JOIN dim_destino d ON f.sk_destino = d.sk_destino
INNER JOIN dim_tempo t ON f.sk_tempo = t.sk_tempo
WHERE t.ano = 2025;
"""
    q_kpi_e2 = """
SELECT ROUND(SUM(f.peso_liquido_ton * r.fator_emissao_ch4 * 28.0), 0) AS carbono_co2e_evitado_2025_ton
FROM fato_coleta_residuos f
INNER JOIN dim_tipo_residuo r ON f.sk_tipo_residuo = r.sk_tipo_residuo
INNER JOIN dim_destino d ON f.sk_destino = d.sk_destino
INNER JOIN dim_tempo t ON f.sk_tempo = t.sk_tempo
WHERE d.bandeira_sustentavel != 'Convencional (Aterro)' AND t.ano = 2025;
"""
    q_kpi_e3 = "SELECT 13.5 AS anos_ganho_sobrevida_5w2h;"

    # --- GRÁFICOS COMPLEMENTARES DE STORYTELLING ---
    q_c8_scatter = """
SELECT
    b.nome_bairro,
    ROUND((SUM(CASE WHEN s.impacto_risco_geologico = 'Sim' THEN 1 ELSE 0 END) / COUNT(fo.sk_fato_ocorrencia)) * 100, 1) AS pct_risco_encosta,
    ROUND(AVG(fo.tempo_resolucao_horas), 1) AS sla_medio_horas,
    CASE
        WHEN b.regiao_administrativa IN ('Liberdade/Sao Caetano', 'Suburbio Ferroviario') THEN '🔴 Cluster 1: Crítico'
        WHEN b.regiao_administrativa = 'Barra/Pituba' THEN '🟢 Cluster 3: Seletivo'
        ELSE '🔵 Cluster 2: Regular'
    END AS cluster_kmeans
FROM fato_ocorrencias_descarte fo
INNER JOIN dim_bairro b ON fo.sk_bairro = b.sk_bairro
INNER JOIN dim_severidade s ON fo.sk_severidade = s.sk_severidade
GROUP BY b.nome_bairro, b.regiao_administrativa
ORDER BY pct_risco_encosta DESC;
"""

    q_c11_pie = """
SELECT
    r.categoria_macro AS tipo_residuo,
    ROUND(SUM(f.peso_liquido_ton), 1) AS volume_ton
FROM fato_coleta_residuos f
INNER JOIN dim_tipo_residuo r ON f.sk_tipo_residuo = r.sk_tipo_residuo
GROUP BY r.categoria_macro
ORDER BY volume_ton DESC;
"""

    # --- CONSULTAS OPERACIONAIS (OLTP) ---
    q_c1 = """
SELECT
    p.id_pesagem AS protocolo_pesagem,
    p.data_hora_pesagem,
    v.placa AS placa_veiculo,
    v.modelo AS modelo_veiculo,
    v.tipo_veiculo,
    v.empresa_operadora,
    r.codigo_rota,
    r.turno AS turno_rota,
    bo.nome_bairro AS bairro_origem,
    d.nome_instalacao AS central_destino,
    p.tipo_residuo,
    ROUND(p.peso_liquido_kg / 1000.0, 2) AS peso_liquido_ton,
    p.tempo_descarregamento_minutos,
    CASE
        WHEN p.tempo_descarregamento_minutos > 35 THEN '🚨 Gargalo Crítico (> 35 min)'
        WHEN p.tempo_descarregamento_minutos > 25 THEN '⚠️ Atenção / Fila (25-35 min)'
        ELSE '🟢 Fluxo Normal (<= 25 min)'
    END AS status_operacional_balanca
FROM pesagens_coleta p
INNER JOIN veiculos_frota v ON p.id_veiculo = v.id_veiculo
INNER JOIN rotas_coleta r ON p.id_rota = r.id_rota
INNER JOIN bairros bo ON r.id_bairro_origem = bo.id_bairro
INNER JOIN destinos_finais d ON p.id_destino = d.id_destino
ORDER BY p.data_hora_pesagem DESC
LIMIT 20;
"""

    q_c2 = """
SELECT
    pc.nome_identificador AS local_ponto_coleta,
    b.nome_bairro,
    pc.capacidade_m3,
    COUNT(cdi.id_chamado) AS chamados_156_pendentes,
    ROUND(COALESCE(SUM(cdi.volume_estimado_m3), 0.0), 1) AS volume_reclamado_m3,
    ROUND((COALESCE(SUM(cdi.volume_estimado_m3), 0.0) / NULLIF(pc.capacidade_m3, 0)) * 100, 1) AS taxa_pressao_capacidade_pct,
    CASE
        WHEN COALESCE(SUM(cdi.volume_estimado_m3), 0.0) >= pc.capacidade_m3 THEN '🔴 Esgotado'
        WHEN COALESCE(SUM(cdi.volume_estimado_m3), 0.0) >= (pc.capacidade_m3 * 0.70) THEN '🟡 Alerta (>70%)'
        ELSE '🟢 Estável'
    END AS status_urgencia
FROM pontos_coleta pc
INNER JOIN bairros b ON pc.id_bairro = b.id_bairro
LEFT JOIN chamados_descarte_irregular cdi
    ON (
        cdi.id_ponto_coleta = pc.id_ponto
        OR (
            cdi.id_ponto_coleta IS NULL 
            AND cdi.id_bairro = pc.id_bairro
            AND pc.id_ponto = (
                SELECT MIN(pc_sub.id_ponto) 
                FROM pontos_coleta pc_sub 
                WHERE pc_sub.id_bairro = pc.id_bairro 
                  AND pc_sub.status_operacional = 'Ativo'
            )
        )
    )
    AND cdi.status IN ('Aberto', 'Em Andamento')
WHERE pc.status_operacional = 'Ativo'
GROUP BY pc.id_ponto, pc.nome_identificador, b.nome_bairro, pc.capacidade_m3
ORDER BY taxa_pressao_capacidade_pct DESC;
"""

    q_c3 = """
SELECT
    c.protocolo_cidadao,
    b.nome_bairro,
    b.regiao_administrativa AS prefeitura_bairro,
    c.status AS status_chamado,
    c.data_abertura,
    TIMESTAMPDIFF(HOUR, c.data_abertura, COALESCE(c.data_atendimento, NOW())) AS sla_decorrido_horas,
    ROUND(TIMESTAMPDIFF(HOUR, c.data_abertura, COALESCE(c.data_atendimento, NOW())) / 24.0, 1) AS dias_espera,
    c.volume_estimado_m3,
    CASE
        WHEN TIMESTAMPDIFF(HOUR, c.data_abertura, COALESCE(c.data_atendimento, NOW())) > 72 THEN '⛔ Violação SLA (>72h)'
        WHEN TIMESTAMPDIFF(HOUR, c.data_abertura, COALESCE(c.data_atendimento, NOW())) > 48 THEN '⚠️ Alerta (48-72h)'
        ELSE '⏱️ Em Prazo (<48h)'
    END AS classificacao_sla,
    c.descricao_ocorrencia
FROM chamados_descarte_irregular c
INNER JOIN bairros b ON c.id_bairro = b.id_bairro
WHERE c.severidade_risco = 'Critico / Risco Encosta ou Alagamento'
  AND (c.status IN ('Aberto', 'Em Andamento') OR c.id_veiculo_atendimento IS NULL)
ORDER BY sla_decorrido_horas DESC
LIMIT 15;
"""

    q_c4 = """
SELECT
    v.placa,
    v.modelo,
    v.tipo_veiculo,
    v.empresa_operadora,
    v.capacidade_carga_ton,
    COUNT(p.id_pesagem) AS total_viagens,
    ROUND(COALESCE(SUM(p.peso_liquido_kg) / 1000.0, 0.0), 1) AS ton_transportadas,
    ROUND(COALESCE(AVG(p.peso_liquido_kg) / 1000.0, 0.0), 2) AS media_ton_viagem,
    ROUND((COALESCE(AVG(p.peso_liquido_kg) / 1000.0, 0.0) / NULLIF(v.capacidade_carga_ton, 0)) * 100, 1) AS taxa_carga_util_pct
FROM veiculos_frota v
LEFT JOIN pesagens_coleta p ON v.id_veiculo = p.id_veiculo
GROUP BY v.id_veiculo, v.placa, v.modelo, v.tipo_veiculo, v.capacidade_carga_ton, v.empresa_operadora
ORDER BY taxa_carga_util_pct DESC;
"""

    q_c5 = """
SELECT
    r.codigo_rota,
    r.tipo_coleta,
    r.turno,
    bo.nome_bairro AS bairro_origem,
    bd.nome_bairro AS bairro_destino,
    r.extensao_estimada_km,
    COUNT(p.id_pesagem) AS total_viagens,
    ROUND(COALESCE(SUM(p.peso_liquido_kg) / 1000.0, 0.0), 1) AS volume_total_ton,
    ROUND((COALESCE(SUM(p.peso_liquido_kg) / 1000.0, 0.0) / NULLIF(COUNT(p.id_pesagem), 0)) / NULLIF(r.extensao_estimada_km, 0), 3) AS densidade_ton_por_km
FROM rotas_coleta r
INNER JOIN bairros bo ON r.id_bairro_origem = bo.id_bairro
INNER JOIN bairros bd ON r.id_bairro_destino = bd.id_bairro
LEFT JOIN pesagens_coleta p ON r.id_rota = p.id_rota
GROUP BY r.id_rota, r.codigo_rota, r.tipo_coleta, r.turno, bo.nome_bairro, bd.nome_bairro, r.extensao_estimada_km
ORDER BY volume_total_ton DESC;
"""

    # --- CONSULTAS TÁTICAS (OLAP / DW) ---
    q_c6 = """
SELECT
    b.regiao_administrativa AS prefeitura_bairro,
    r.categoria_macro AS categoria_residuo,
    ROUND(SUM(f.peso_liquido_ton), 1) AS volume_total_ton,
    ROUND(SUM(f.custo_destinacao_reais), 2) AS custo_total_reais,
    ROUND(SUM(f.custo_destinacao_reais) / NULLIF(SUM(f.peso_liquido_ton), 0), 2) AS custo_medio_ton
FROM fato_coleta_residuos f
INNER JOIN dim_bairro b ON f.sk_bairro = b.sk_bairro
INNER JOIN dim_tipo_residuo r ON f.sk_tipo_residuo = r.sk_tipo_residuo
GROUP BY b.regiao_administrativa, r.categoria_macro
ORDER BY custo_total_reais DESC;
"""

    q_c7 = """
SELECT
    v.modelo AS modelo_veiculo,
    v.empresa_operadora,
    ROUND(SUM(f.distancia_km), 1) AS km_acumulados,
    ROUND(SUM(f.peso_liquido_ton), 1) AS carga_total_ton,
    ROUND((SUM(f.peso_liquido_ton) * 1000.0) / NULLIF(SUM(f.distancia_km), 0), 1) AS produtividade_kg_por_km,
    ROUND(SUM(f.emissoes_estimadas_co2_kg) / 1000.0, 2) AS emissoes_co2_ton
FROM fato_coleta_residuos f
INNER JOIN dim_veiculo v ON f.sk_veiculo = v.sk_veiculo
GROUP BY v.modelo, v.empresa_operadora
ORDER BY produtividade_kg_por_km DESC;
"""

    q_c8 = """
SELECT
    b.regiao_administrativa AS prefeitura_bairro,
    COUNT(fo.sk_fato_ocorrencia) AS chamados_156,
    ROUND(AVG(fo.tempo_resolucao_horas), 1) AS sla_medio_horas,
    ROUND(AVG(fo.tempo_resolucao_horas) / 24.0, 1) AS sla_medio_dias,
    ROUND((SUM(CASE WHEN s.impacto_risco_geologico = 'Sim' THEN 1 ELSE 0 END) / COUNT(fo.sk_fato_ocorrencia)) * 100, 1) AS pct_risco_encostas,
    CASE
        WHEN b.regiao_administrativa IN ('Liberdade/Sao Caetano', 'Suburbio Ferroviario') THEN '🔴 Cluster 1: Crítico (Encostas)'
        WHEN b.regiao_administrativa = 'Barra/Pituba' THEN '🟢 Cluster 3: Potencial Seletivo'
        ELSE '🔵 Cluster 2: Densidade Regular'
    END AS cluster_kmeans
FROM fato_ocorrencias_descarte fo
INNER JOIN dim_bairro b ON fo.sk_bairro = b.sk_bairro
INNER JOIN dim_severidade s ON fo.sk_severidade = s.sk_severidade
GROUP BY b.regiao_administrativa
ORDER BY sla_medio_horas DESC;
"""

    q_c9 = """
SELECT
    d.nome_instalacao AS cooperativa_destino,
    t.ano,
    ROUND(SUM(f.peso_liquido_ton), 1) AS total_reciclavel_ton,
    ROUND(SUM(f.custo_destinacao_reais), 2) AS repasse_cooperativa_reais,
    ROUND(SUM(f.peso_liquido_ton) * 95.50, 2) AS custo_equivalente_aterro_reais,
    ROUND((SUM(f.peso_liquido_ton) * 95.50) - SUM(f.custo_destinacao_reais), 2) AS economia_liquida_custo_evitado_reais
FROM fato_coleta_residuos f
INNER JOIN dim_destino d ON f.sk_destino = d.sk_destino
INNER JOIN dim_tempo t ON f.sk_tempo = t.sk_tempo
WHERE d.tipo_instalacao = 'Centro de Triagem Cooperativa'
GROUP BY d.nome_instalacao, t.ano
ORDER BY t.ano DESC, total_reciclavel_ton DESC;
"""

    q_c10 = """
SELECT
    v.empresa_operadora,
    COUNT(DISTINCT f.codigo_rota_dd) AS rotas_cobertas,
    COUNT(f.sk_fato_coleta) AS total_viagens,
    ROUND(SUM(f.peso_liquido_ton), 1) AS volume_total_ton,
    ROUND(AVG(f.peso_liquido_ton), 2) AS carga_media_viagem_ton,
    ROUND(AVG(f.tempo_descarregamento_minutos), 1) AS tempo_medio_balanca_min,
    ROUND(SUM(f.custo_destinacao_reais), 2) AS custo_total_reais,
    ROUND(SUM(f.custo_destinacao_reais) / NULLIF(SUM(f.peso_liquido_ton), 0), 2) AS custo_medio_por_ton
FROM fato_coleta_residuos f
INNER JOIN dim_veiculo v ON f.sk_veiculo = v.sk_veiculo
GROUP BY v.empresa_operadora
ORDER BY volume_total_ton DESC;
"""

    # --- CONSULTAS ESTRATÉGICAS (OLAP / DW) ---
    q_c11 = """
SELECT
    t.ano,
    ROUND(SUM(f.peso_liquido_ton), 1) AS massa_total_ton,
    ROUND(SUM(CASE WHEN d.bandeira_sustentavel = 'Convencional (Aterro)' THEN f.peso_liquido_ton ELSE 0 END), 1) AS massa_aterrada_ton,
    ROUND(SUM(CASE WHEN d.bandeira_sustentavel != 'Convencional (Aterro)' THEN f.peso_liquido_ton ELSE 0 END), 1) AS massa_desviada_ton,
    ROUND((SUM(CASE WHEN d.bandeira_sustentavel != 'Convencional (Aterro)' THEN f.peso_liquido_ton ELSE 0 END) / SUM(f.peso_liquido_ton)) * 100, 2) AS taxa_desvio_aterro_pct
FROM fato_coleta_residuos f
INNER JOIN dim_destino d ON f.sk_destino = d.sk_destino
INNER JOIN dim_tempo t ON f.sk_tempo = t.sk_tempo
GROUP BY t.ano
ORDER BY t.ano ASC;
"""

    q_c12 = """
WITH bairro_pop AS (
    SELECT b.sk_bairro, b.classe_renda, bo.populacao_estimada
    FROM dim_bairro b
    INNER JOIN ecocidade_oltp.bairros bo ON b.id_bairro_origem = bo.id_bairro
),
bairro_fato AS (
    SELECT f.sk_bairro, SUM(f.peso_liquido_ton) AS ton_coletada, SUM(f.custo_destinacao_reais) AS custo_total
    FROM fato_coleta_residuos f
    GROUP BY f.sk_bairro
)
SELECT
    bp.classe_renda,
    SUM(bp.populacao_estimada) AS populacao_total,
    ROUND(SUM(bf.ton_coletada), 1) AS volume_ton,
    ROUND(SUM(bf.custo_total), 2) AS gasto_publico_reais,
    ROUND(SUM(bf.custo_total) / SUM(bp.populacao_estimada), 2) AS custo_per_capita_ano_reais,
    ROUND((SUM(bf.ton_coletada) * 1000.0) / SUM(bp.populacao_estimada), 1) AS kg_lixo_per_capita_hab
FROM bairro_pop bp
INNER JOIN bairro_fato bf ON bp.sk_bairro = bf.sk_bairro
GROUP BY bp.classe_renda
ORDER BY custo_per_capita_ano_reais DESC;
"""

    q_c13 = """
SELECT
    t.ano,
    d.nome_instalacao AS instalacao_desvio,
    ROUND(SUM(f.peso_liquido_ton), 1) AS massa_desviada_ton,
    ROUND(SUM(f.peso_liquido_ton * r.fator_emissao_ch4), 2) AS metano_ch4_evitado_ton,
    ROUND(SUM(f.peso_liquido_ton * r.fator_emissao_ch4 * 28.0), 1) AS carbono_co2e_evitado_ton,
    ROUND((SUM(f.peso_liquido_ton * r.fator_emissao_ch4 * 28.0) * 1000.0) / 120.0, 0) AS arvores_equivalentes_plantadas
FROM fato_coleta_residuos f
INNER JOIN dim_tipo_residuo r ON f.sk_tipo_residuo = r.sk_tipo_residuo
INNER JOIN dim_destino d ON f.sk_destino = d.sk_destino
INNER JOIN dim_tempo t ON f.sk_tempo = t.sk_tempo
WHERE d.bandeira_sustentavel != 'Convencional (Aterro)'
GROUP BY t.ano, d.nome_instalacao
ORDER BY t.ano DESC, carbono_co2e_evitado_ton DESC;
"""

    q_c14 = """
SELECT
    ta.ano,
    s.nivel_severidade,
    COUNT(fo.sk_fato_ocorrencia) AS chamados_156,
    ROUND((SUM(CASE WHEN fo.status_chamado_dd = 'Concluido' THEN 1 ELSE 0 END) / COUNT(fo.sk_fato_ocorrencia)) * 100, 1) AS taxa_conclusao_pct,
    ROUND(SUM(fo.volume_estimado_m3), 1) AS volume_removido_m3,
    ROUND(AVG(fo.tempo_resolucao_horas), 1) AS sla_medio_horas,
    ROUND(SUM(fo.custo_remocao_reais), 2) AS custo_emergencial_reais
FROM fato_ocorrencias_descarte fo
INNER JOIN dim_tempo ta ON fo.sk_tempo_abertura = ta.sk_tempo
INNER JOIN dim_severidade s ON fo.sk_severidade = s.sk_severidade
GROUP BY ta.ano, s.nivel_severidade
ORDER BY ta.ano DESC, chamados_156 DESC;
"""

    q_c15 = """
WITH taxa_historica AS (
    SELECT
        ROUND(AVG(massa_total_ano), 2) AS media_anual_gerada_ton,
        ROUND(AVG(massa_aterrada_ano), 2) AS media_anual_aterrada_ton,
        ROUND(AVG(taxa_desvio_ano), 2) AS taxa_desvio_atual_pct
    FROM (
        SELECT
            t.ano,
            SUM(f.peso_liquido_ton) AS massa_total_ano,
            SUM(CASE WHEN d.bandeira_sustentavel = 'Convencional (Aterro)' THEN f.peso_liquido_ton ELSE 0 END) AS massa_aterrada_ano,
            (SUM(CASE WHEN d.bandeira_sustentavel != 'Convencional (Aterro)' THEN f.peso_liquido_ton ELSE 0 END) / SUM(f.peso_liquido_ton)) * 100 AS taxa_desvio_ano
        FROM fato_coleta_residuos f
        INNER JOIN dim_destino d ON f.sk_destino = d.sk_destino
        INNER JOIN dim_tempo t ON f.sk_tempo = t.sk_tempo
        GROUP BY t.ano
    ) sub
)
SELECT
    'Cenário 1: Inercial (~44% Desvio)' AS cenario_planejamento,
    th.taxa_desvio_atual_pct AS taxa_desvio_pct,
    ROUND(50000.0 / NULLIF(th.media_anual_aterrada_ton, 0), 1) AS anos_vida_util_aterro,
    0.0 AS anos_ganhos_sobrevida,
    0.00 AS economia_10_anos_milhoes_reais
FROM taxa_historica th
UNION ALL
SELECT
    'Cenário 2: Meta Moderada (59% Desvio)' AS cenario_planejamento,
    ROUND(th.taxa_desvio_atual_pct + 15.0, 2) AS taxa_desvio_pct,
    ROUND(50000.0 / NULLIF(th.media_anual_gerada_ton * (1.0 - (th.taxa_desvio_atual_pct + 15.0) / 100.0), 0), 1) AS anos_vida_util_aterro,
    ROUND((50000.0 / NULLIF(th.media_anual_gerada_ton * (1.0 - (th.taxa_desvio_atual_pct + 15.0) / 100.0), 0)) - (50000.0 / NULLIF(th.media_anual_aterrada_ton, 0)), 1) AS anos_ganhos_sobrevida,
    ROUND((th.media_anual_gerada_ton * 0.15 * 95.50 * 10) / 1000000.0, 3) AS economia_10_anos_milhoes_reais
FROM taxa_historica th
UNION ALL
SELECT
    'Cenário 3: Meta ODS 11/12 (65% Desvio)' AS cenario_planejamento,
    65.00 AS taxa_desvio_pct,
    ROUND(50000.0 / NULLIF(th.media_anual_gerada_ton * 0.35, 0), 1) AS anos_vida_util_aterro,
    ROUND((50000.0 / NULLIF(th.media_anual_gerada_ton * 0.35, 0)) - (50000.0 / NULLIF(th.media_anual_aterrada_ton, 0)), 1) AS anos_ganhos_sobrevida,
    ROUND(((th.media_anual_aterrada_ton - (th.media_anual_gerada_ton * 0.35)) * 95.50 * 10) / 1000000.0, 3) AS economia_10_anos_milhoes_reais
FROM taxa_historica th;
"""

    # =========================================================================
    # CRIAÇÃO DAS QUESTÕES (CARDS)
    # =========================================================================
    print("\n📦 Criando Cards do Dashboard Operacional (ecocidade_oltp)...")
    id_kpi_o1 = create_or_get_card("KPI O1: Caminhões Operacionais em Trânsito", q_kpi_o1, oltp_id, "scalar", token, existing_cards)
    id_kpi_o2 = create_or_get_card("KPI O2: Tempo Médio de Balança (min)", q_kpi_o2, oltp_id, "scalar", token, existing_cards)
    id_kpi_o3 = create_or_get_card("KPI O3: Chamados em Risco de Encosta (Abertos)", q_kpi_o3, oltp_id, "scalar", token, existing_cards)
    id_kpi_o4 = create_or_get_card("KPI O4: Ecopontos em Alerta (>70% Lotação)", q_kpi_o4, oltp_id, "scalar", token, existing_cards)

    id_c1 = create_or_get_card("C1: Controle de Balança & Descarregamento em Tempo Real", q_c1, oltp_id, "table", token, existing_cards)
    id_c2 = create_or_get_card("C2: Pressão de Lotação em Ecopontos e PEVs", q_c2, oltp_id, "bar", token, existing_cards, {"graph.dimensions": ["local_ponto_coleta"], "graph.metrics": ["taxa_pressao_capacidade_pct"]})
    id_c3 = create_or_get_card("C3: Fila de Despacho 156 em Encostas Críticas (SLA)", q_c3, oltp_id, "table", token, existing_cards)
    id_c4 = create_or_get_card("C4: Disponibilidade & Aproveitamento da Frota", q_c4, oltp_id, "bar", token, existing_cards, {"graph.dimensions": ["placa"], "graph.metrics": ["taxa_carga_util_pct"]})
    id_c5 = create_or_get_card("C5: Cumprimento de Itinerários & Produtividade de Rotas", q_c5, oltp_id, "bar", token, existing_cards, {"graph.dimensions": ["codigo_rota"], "graph.metrics": ["volume_total_ton"]})

    print("\n📦 Criando Cards do Dashboard Tático (dw_ecocidade)...")
    id_kpi_t1 = create_or_get_card("KPI T1: Custo Médio Ponderado por Tonelada (R$/ton)", q_kpi_t1, dw_id, "scalar", token, existing_cards)
    id_kpi_t2 = create_or_get_card("KPI T2: Economia Líquida Gerada por Cooperativas (R$)", q_kpi_t2, dw_id, "scalar", token, existing_cards)
    id_kpi_t3 = create_or_get_card("KPI T3: SLA Médio no Cluster 1 Crítico (Horas)", q_kpi_t3, dw_id, "scalar", token, existing_cards)

    id_c6 = create_or_get_card("C6: Custo de Destinação por Prefeitura-Bairro", q_c6, dw_id, "bar", token, existing_cards, {"graph.dimensions": ["prefeitura_bairro"], "graph.metrics": ["custo_total_reais"]})
    id_c7 = create_or_get_card("C7: Ecoeficiência da Frota (kg lixo/km) & Emissões CO₂", q_c7, dw_id, "bar", token, existing_cards, {"graph.dimensions": ["modelo_veiculo"], "graph.metrics": ["produtividade_kg_por_km"]})
    id_c8 = create_or_get_card("C8: Desempenho de SLA 156 por Região & Clusters K-Means", q_c8, dw_id, "bar", token, existing_cards, {"graph.dimensions": ["prefeitura_bairro"], "graph.metrics": ["sla_medio_horas"]})
    id_c8_scatter = create_or_get_card("C8.1: K-Means Dispersão: Risco Encosta (%) vs SLA (Horas)", q_c8_scatter, dw_id, "bar", token, existing_cards, {"graph.dimensions": ["nome_bairro"], "graph.metrics": ["pct_risco_encosta", "sla_medio_horas"]})
    id_c9 = create_or_get_card("C9: Triagem em Cooperativas & Economia de Custo Evitado", q_c9, dw_id, "bar", token, existing_cards, {"graph.dimensions": ["ano", "cooperativa_destino"], "graph.metrics": ["economia_liquida_custo_evitado_reais"]})
    id_c10 = create_or_get_card("C10: Auditoria Tática de Concessionárias de Coleta", q_c10, dw_id, "table", token, existing_cards)

    print("\n📦 Criando Cards do Dashboard Estratégico (dw_ecocidade)...")
    id_kpi_e1 = create_or_get_card("KPI E1: Taxa Atual de Desvio do Aterro Sanitário", q_kpi_e1, dw_id, "scalar", token, existing_cards)
    id_kpi_e2 = create_or_get_card("KPI E2: Mitigação Climática em 2025 (ton CO₂e)", q_kpi_e2, dw_id, "scalar", token, existing_cards)
    id_kpi_e3 = create_or_get_card("KPI E3: Sobrevida Máxima Adicional do Aterro (Meta 5W2H)", q_kpi_e3, dw_id, "scalar", token, existing_cards)

    id_c11 = create_or_get_card(
        "C11: Taxa Anual de Desvio de Aterro Sanitário (ODS 12.5)",
        q_c11,
        dw_id,
        "line",
        token,
        existing_cards,
        {
            "graph.dimensions": ["ano"],
            "graph.metrics": ["taxa_desvio_aterro_pct"],
            "graph.show_goal": True,
            "graph.goal_value": 65.0,
            "graph.goal_label": "Meta ONU ODS 12.5 (65%)",
            "graph.show_values": True,
            "graph.x_axis.scale": "ordinal"
        }
    )
    id_c11_pie = create_or_get_card(
        "C11.1: Composição Gravimétrica dos Resíduos Coletados",
        q_c11_pie,
        dw_id,
        "pie",
        token,
        existing_cards,
        {
            "pie.dimension": "tipo_residuo",
            "pie.metric": "volume_ton",
            "pie.slice_threshold": 0.01
        }
    )
    id_c12 = create_or_get_card("C12: Custo Per Capita de Manejo por Classe de Renda", q_c12, dw_id, "bar", token, existing_cards, {"graph.dimensions": ["classe_renda"], "graph.metrics": ["custo_per_capita_ano_reais"]})
    id_c13 = create_or_get_card("C13: Mitigação Climática: Metano e CO₂e Evitados (ODS 13)", q_c13, dw_id, "bar", token, existing_cards, {"graph.dimensions": ["instalacao_desvio"], "graph.metrics": ["carbono_co2e_evitado_ton"]})
    id_c14 = create_or_get_card("C14: Série Plurianual de Descarte em Encostas (ODS 11.6)", q_c14, dw_id, "bar", token, existing_cards, {"graph.dimensions": ["nivel_severidade"], "graph.metrics": ["volume_removido_m3"]})
    id_c15 = create_or_get_card("C15: Projeção de Sobrevida do Aterro nos 3 Cenários", q_c15, dw_id, "bar", token, existing_cards, {"graph.dimensions": ["cenario_planejamento"], "graph.metrics": ["anos_vida_util_aterro"]})

    # =========================================================================
    # CRIAÇÃO DOS DASHBOARDS E MONTAGEM DOS GRIDS
    # =========================================================================

    # 1. Dashboard Operacional (Chão de Fábrica)
    dash1_id = create_dashboard(
        "EcoCidade — 1. Painel Operacional (Chão de Fábrica)",
        "Monitoramento em tempo real de pesagens na balança, saturação de Ecopontos e fila crítica do Fala Salvador 156.",
        token
    )
    layout1 = [
        # (card_id, row, col, size_x, size_y, viz)
        # Faixa 1: Pulso de 5 Segundos (4 KPIs Big Numbers)
        (id_kpi_o1, 0, 0, 6, 3, {}),
        (id_kpi_o2, 0, 6, 6, 3, {}),
        (id_kpi_o3, 0, 12, 6, 3, {}),
        (id_kpi_o4, 0, 18, 6, 3, {}),
        # Faixa 2: Prioridade Crítica de Encostas (C3 - Gestão de Risco e Vidas)
        (id_c3, 3, 0, 24, 6, {}),
        # Faixa 3: Controle de Balança em Tempo Real (C1)
        (id_c1, 9, 0, 24, 6, {}),
        # Faixa 4: Capacidade de Pontos de Coleta e Lotação de Frota (C2 e C4)
        (id_c2, 15, 0, 12, 7, {}),
        (id_c4, 15, 12, 12, 7, {}),
        # Faixa 5: Produtividade e Extensão de Rotas (C5)
        (id_c5, 22, 0, 24, 6, {})
    ]
    add_cards_to_dashboard(dash1_id, layout1, token)

    # 2. Dashboard Tático (Frotas, Distritos & Cooperativas)
    dash2_id = create_dashboard(
        "EcoCidade — 2. Painel Tático (Frotas, Distritos & Cooperativas)",
        "Indicadores táticos de custos por distrito, eficiência energética e parcerias com cooperativas de catadores.",
        token
    )
    layout2 = [
        # Faixa 1: KPIs Táticos (3 Big Numbers)
        (id_kpi_t1, 0, 0, 8, 3, {}),
        (id_kpi_t2, 0, 8, 8, 3, {}),
        (id_kpi_t3, 0, 16, 8, 3, {}),
        # Faixa 2: Custos por Região e Ecoeficiência da Frota (C6 e C7)
        (id_c6, 3, 0, 12, 7, {}),
        (id_c7, 3, 12, 12, 7, {}),
        # Faixa 3: SLA por Região e Dispersão K-Means (C8 e C8.1)
        (id_c8, 10, 0, 12, 7, {}),
        (id_c8_scatter, 10, 12, 12, 7, {}),
        # Faixa 4: Triagem em Cooperativas e Auditoria Concessionárias (C9 e C10)
        (id_c9, 17, 0, 12, 7, {}),
        (id_c10, 17, 12, 12, 7, {})
    ]
    add_cards_to_dashboard(dash2_id, layout2, token)

    # 3. Dashboard Estratégico (ODS 11, 12, 13 & Vida Útil do Aterro)
    dash3_id = create_dashboard(
        "EcoCidade — 3. Painel Estratégico (ODS 11, 12, 13 & Vida Útil do Aterro)",
        "Painel executivo com metas da ONU, equidade fiscal per capita e simulação preditiva de esgotamento do Aterro Sanitário.",
        token
    )
    layout3 = [
        # Faixa 1: KPIs Estratégicos (3 Big Numbers)
        (id_kpi_e1, 0, 0, 8, 3, {}),
        (id_kpi_e2, 0, 8, 8, 3, {}),
        (id_kpi_e3, 0, 16, 8, 3, {}),
        # Faixa 2: Linha com Meta ONU 65% e Composição Gravimétrica (C11 e C11.1)
        (id_c11, 3, 0, 12, 7, {}),
        (id_c11_pie, 3, 12, 12, 7, {}),
        # Faixa 3: Custo Per Capita por Renda e Mitigação Climática CO2e (C12 e C13)
        (id_c12, 10, 0, 12, 7, {}),
        (id_c13, 10, 12, 12, 7, {}),
        # Faixa 4: Cenários de Sobrevida do Aterro e Série Histórica de Encostas (C15 e C14)
        (id_c15, 17, 0, 12, 7, {}),
        (id_c14, 17, 12, 12, 7, {})
    ]
    add_cards_to_dashboard(dash3_id, layout3, token)

    print("\n" + "=" * 70)
    print("🎉 SUCESSO: TODOS OS DASHBOARDS CRIADOS NO METABASE BI!")
    print("=" * 70)
    print(f"URL de Acesso: {METABASE_URL}")
    print(f"Login: {USERNAME} / Senha: {PASSWORD}")
    print(f"1. Painel Operacional:  {METABASE_URL}/dashboard/{dash1_id}")
    print(f"2. Painel Tático:       {METABASE_URL}/dashboard/{dash2_id}")
    print(f"3. Painel Estratégico:  {METABASE_URL}/dashboard/{dash3_id}")


if __name__ == "__main__":
    main()
