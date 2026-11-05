"""
Pipeline de Mineração de Dados e Análise Exploratória (K-Means)
Projeto EcoCidade — Laboratório de Dados para Cidades Sustentáveis (PBL)
Disciplina: Tópicos Especiais em Banco de Dados — UNEB
Docente: Prof. Me. Antônio José A. Cordeiro

Objetivo:
- Segmentar os 16 bairros de Salvador em clusters operacionais homogêneos
  baseados em indicadores de demanda 156, vulnerabilidade geológica e potencial de reciclagem.
- Gerar visualizações gráficas científicas (Cotovelo, Silhueta, PCA 2D e Radar).
- Salvar dataset enriquecido com a rotulagem para suporte aos Dashboards (Itens 7 a 9) e 5W2H (Item 10).
"""

import os
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.preprocessing import StandardScaler
from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score
from sklearn.decomposition import PCA

# Configuração visual profissional
plt.style.use('seaborn-v0_8-whitegrid')
plt.rcParams['font.family'] = 'DejaVu Sans'
plt.rcParams['font.size'] = 10
plt.rcParams['axes.titlesize'] = 12
plt.rcParams['axes.labelsize'] = 11

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DADOS_IN = os.path.join(BASE_DIR, 'dados', 'salvador_156_limpeza_urbana_2024.csv')
GRAFICOS_DIR = os.path.join(BASE_DIR, 'graficos')
CSV_OUT = os.path.join(BASE_DIR, 'dados', 'clusters_salvador_kmeans.csv')

os.makedirs(GRAFICOS_DIR, exist_ok=True)

print("=" * 70)
print("ECOCIDADE — MINERAÇÃO DE DADOS K-MEANS (ITEM 6)")
print("=" * 70)

# 1. Carregamento dos dados
print(f"Lendo base consolidada: {DADOS_IN}")
df_raw = pd.read_csv(DADOS_IN)
print(f"Total de chamados carregados: {len(df_raw):,} registros.")

# 2. Engenharia de Atributos (Feature Engineering por Bairro)
print("\nAgregando indicadores operacionais e territoriais por bairro...")
bairros_df = df_raw.groupby([
    'id_bairro', 'bairro', 'prefeitura_bairro', 'populacao_bairro', 'area_km2', 'renda_media_domiciliar'
]).agg(
    total_chamados=('protocolo', 'count'),
    vol_total_m3=('volume_estimado_m3', 'sum'),
    sla_medio_horas=('sla_horas', 'mean'),
    chamados_entulho=('tipo_servico', lambda s: (s == 'REMOCAO DE ENTULHOS').sum()),
    chamados_seletiva=('tipo_servico', lambda s: (s == 'IMP. COLETA SELETIVA').sum()),
    chamados_encosta=('severidade_risco', lambda s: (s == 'Critico / Risco Encosta ou Alagamento').sum())
).reset_index()

# Métricas relativas
bairros_df['densidade_chamados_hab'] = (bairros_df['total_chamados'] / bairros_df['populacao_bairro']) * 1000
bairros_df['taxa_entulho_pct'] = (bairros_df['chamados_entulho'] / bairros_df['total_chamados']) * 100
bairros_df['taxa_seletiva_pct'] = (bairros_df['chamados_seletiva'] / bairros_df['total_chamados']) * 100
bairros_df['taxa_critica_encosta_pct'] = (bairros_df['chamados_encosta'] / bairros_df['total_chamados']) * 100
bairros_df['vol_medio_m3'] = bairros_df['vol_total_m3'] / bairros_df['total_chamados']

features = [
    'densidade_chamados_hab',
    'taxa_entulho_pct',
    'taxa_seletiva_pct',
    'taxa_critica_encosta_pct',
    'sla_medio_horas',
    'renda_media_domiciliar'
]

features_labels = [
    'Densidade Chamados (/1k hab)',
    'Taxa Entulho Clandestino (%)',
    'Demanda Coleta Seletiva (%)',
    'Risco de Encosta / Alagamento (%)',
    'SLA Médio de Atendimento (h)',
    'Renda Média Domiciliar (R$)'
]

# 3. Padronização Z-Score
X = bairros_df[features].values
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

# 4. Diagnóstico de K Ótimo (Elbow Method & Silhouette Score)
print("\nCalculando inércia e silhueta para k de 2 a 6...")
k_range = range(2, 7)
inertias = []
silhouettes = []

for k in k_range:
    km = KMeans(n_clusters=k, random_state=42, n_init=20)
    labels = km.fit_predict(X_scaled)
    inertias.append(km.inertia_)
    silhouettes.append(silhouette_score(X_scaled, labels))
    print(f"k = {k} -> Inércia (WCSS): {km.inertia_:.2f} | Coeficiente Silhueta: {silhouettes[-1]:.4f}")

# Gráfico 1: Elbow Method & Silhouette
fig, ax1 = plt.subplots(figsize=(8, 4.5), dpi=300)

color_wcss = '#1f77b4'
ax1.set_xlabel('Número de Clusters (k)', fontweight='bold')
ax1.set_ylabel('Inércia / WCSS (Soma de Quadrados Intra-Cluster)', color=color_wcss, fontweight='bold')
line1 = ax1.plot(k_range, inertias, marker='o', linewidth=2.2, color=color_wcss, label='Inércia (WCSS)')
ax1.tick_params(axis='y', labelcolor=color_wcss)
ax1.set_xticks(k_range)

ax2 = ax1.twinx()
color_sil = '#2ca02c'
ax2.set_ylabel('Coeficiente de Silhueta Médio', color=color_sil, fontweight='bold')
line2 = ax2.plot(k_range, silhouettes, marker='s', linewidth=2.2, linestyle='--', color=color_sil, label='Silhueta Média')
ax2.tick_params(axis='y', labelcolor=color_sil)
ax2.grid(False)

# Destaque do k=3
ax1.axvline(x=3, color='#d62728', linestyle=':', linewidth=1.8, label='k=3 (Ponto Ótimo de Negócio)')
lines = line1 + line2 + [plt.Line2D([0], [0], color='#d62728', linestyle=':', linewidth=1.8)]
labels = [l.get_label() for l in lines]
ax1.legend(lines, labels, loc='center right', frameon=True)

plt.title('Diagnóstico Experimental do k Ótimo: Método do Cotovelo & Silhueta', fontweight='bold', pad=15)
fig.tight_layout()
fig_cotovelo = os.path.join(GRAFICOS_DIR, '01_curva_cotovelo_silhueta.png')
plt.savefig(fig_cotovelo)
plt.close()
print(f"Salvo: {fig_cotovelo}")

# 5. Ajuste Final do Modelo com k=3
k_final = 3
km_final = KMeans(n_clusters=k_final, random_state=42, n_init=30)
cluster_raw = km_final.fit_predict(X_scaled)

# Mapear clusters para nomes semânticos claros
# Avaliando centróides para garantir nomenclatura consistente
cluster_means = pd.DataFrame(X, columns=features).groupby(cluster_raw).mean()
# Cluster com maior taxa_critica_encosta_pct -> "Cluster Crítico: Encostas & Entulho"
critico_id = cluster_means['taxa_critica_encosta_pct'].idxmax()
# Cluster com maior renda_media_domiciliar -> "Cluster Nobre: Potencial Seletivo"
nobre_id = cluster_means['renda_media_domiciliar'].idxmax()
# O remanescente -> "Cluster Operacional: Densidade Domiciliar Padrão"
regular_id = [c for c in range(3) if c not in [critico_id, nobre_id]][0]

cluster_map = {
    critico_id: {
        "codigo": "C1_CRITICO",
        "nome": "Crítico: Entulho & Encostas",
        "cor": "#d62728",
        "descricao": "Bairros periféricos de alta declividade com severo descarte clandestino de entulho e risco geotécnico."
    },
    regular_id: {
        "codigo": "C2_REGULAR",
        "nome": "Operacional: Densidade Domiciliar Padrão",
        "cor": "#1f77b4",
        "descricao": "Bairros centrais e populosos com alta geração regular de lixo orgânico e necessidade de rotas noturnas."
    },
    nobre_id: {
        "codigo": "C3_SELETIVA",
        "nome": "Potencial Seletivo: Bairros Verdes",
        "cor": "#2ca02c",
        "descricao": "Orla marítima e bairros nobres com alta renda, baixa incidência de entulho em encostas e alta adesão à reciclagem."
    }
}

bairros_df['cluster_id'] = cluster_raw
bairros_df['cluster_codigo'] = bairros_df['cluster_id'].map(lambda x: cluster_map[x]['codigo'])
bairros_df['cluster_nome'] = bairros_df['cluster_id'].map(lambda x: cluster_map[x]['nome'])

# 6. Gráfico 2: Projeção 2D com PCA (Componentes Principais)
pca = PCA(n_components=2, random_state=42)
X_pca = pca.fit_transform(X_scaled)
bairros_df['pca1'] = X_pca[:, 0]
bairros_df['pca2'] = X_pca[:, 1]

var_exp = pca.explained_variance_ratio_ * 100

fig, ax = plt.subplots(figsize=(10, 6.5), dpi=300)

for cid, cinfo in cluster_map.items():
    sub = bairros_df[bairros_df['cluster_id'] == cid]
    ax.scatter(sub['pca1'], sub['pca2'], color=cinfo['cor'], label=cinfo['nome'], s=140, edgecolors='black', alpha=0.85, zorder=3)
    for _, row in sub.iterrows():
        ax.annotate(
            row['bairro'],
            (row['pca1'], row['pca2']),
            xytext=(6, 4),
            textcoords='offset points',
            fontsize=9,
            fontweight='semibold',
            color='#222222',
            bbox=dict(boxstyle='round,pad=0.2', facecolor='white', alpha=0.65, edgecolor='none')
        )

ax.axhline(0, color='gray', linestyle='--', linewidth=0.8, alpha=0.6)
ax.axvline(0, color='gray', linestyle='--', linewidth=0.8, alpha=0.6)
ax.set_xlabel(f'Primeira Componente Principal - PC1 ({var_exp[0]:.1f}% da variância)', fontweight='bold')
ax.set_ylabel(f'Segunda Componente Principal - PC2 ({var_exp[1]:.1f}% da variância)', fontweight='bold')
ax.set_title('Mapeamento Territorial 2D dos Bairros de Salvador por PCA & K-Means (k=3)', fontweight='bold', pad=15)
ax.legend(title='Clusters Operacionais Identificados', loc='lower right', frameon=True, fontsize=9)

fig.tight_layout()
fig_pca = os.path.join(GRAFICOS_DIR, '02_dispersao_clusters_pca.png')
plt.savefig(fig_pca)
plt.close()
print(f"Salvo: {fig_pca}")

# 7. Gráfico 3: Radar Chart (Spider Chart dos Centróides)
# Normalização min-max das médias para visualização radar em escala 0-1
features_norm = []
for feat in features:
    min_v = bairros_df[feat].min()
    max_v = bairros_df[feat].max()
    bairros_df[f'{feat}_norm'] = (bairros_df[feat] - min_v) / (max_v - min_v)
    features_norm.append(f'{feat}_norm')

radar_labels = [
    'Densidade\nChamados',
    'Taxa\nEntulho',
    'Demanda\nSeletiva',
    'Risco de\nEncostas',
    'SLA Médio\nAtendimento',
    'Renda Média\nDomiciliar'
]

num_vars = len(radar_labels)
angles = np.linspace(0, 2 * np.pi, num_vars, endpoint=False).tolist()
angles += angles[:1]  # fechar o polígono

fig, ax = plt.subplots(figsize=(8, 8), subplot_kw=dict(polar=True), dpi=300)

for cid, cinfo in cluster_map.items():
    sub = bairros_df[bairros_df['cluster_id'] == cid]
    means_norm = sub[features_norm].mean().tolist()
    means_norm += means_norm[:1]
    
    ax.plot(angles, means_norm, color=cinfo['cor'], linewidth=2.5, label=cinfo['nome'])
    ax.fill(angles, means_norm, color=cinfo['cor'], alpha=0.2)

ax.set_theta_offset(np.pi / 2)
ax.set_theta_direction(-1)
ax.set_thetagrids(np.degrees(angles[:-1]), radar_labels, fontweight='bold', fontsize=9.5)
ax.set_ylim(0, 1.05)
ax.set_yticks([0.25, 0.50, 0.75, 1.0])
ax.set_yticklabels(['25%', '50%', '75%', '100%'], color='gray', size=8)

plt.title('Assinatura Operacional dos Centróides de Limpeza Urbana (Radar Multidimensional)', fontweight='bold', pad=25, size=13)
plt.legend(loc='upper right', bbox_to_anchor=(1.25, 1.15), frameon=True)

fig.tight_layout()
fig_radar = os.path.join(GRAFICOS_DIR, '03_radar_perfis_clusters.png')
plt.savefig(fig_radar)
plt.close()
print(f"Salvo: {fig_radar}")

# 8. Gráfico 4: Matriz Comparativa de Bairros por Cluster (Heatmap / Barras)
fig, axes = plt.subplots(1, 2, figsize=(14, 6), dpi=300)

# Gráfico A: Risco de Encosta vs Demanda Seletiva
for cid, cinfo in cluster_map.items():
    sub = bairros_df[bairros_df['cluster_id'] == cid]
    axes[0].scatter(
        sub['taxa_critica_encosta_pct'], sub['taxa_seletiva_pct'],
        color=cinfo['cor'], label=cinfo['nome'], s=120, edgecolors='black', alpha=0.85
    )
    for _, row in sub.iterrows():
        axes[0].annotate(
            row['bairro'], (row['taxa_critica_encosta_pct'], row['taxa_seletiva_pct']),
            xytext=(4, 3), textcoords='offset points', fontsize=8
        )

axes[0].set_title('Vulnerabilidade Geológica vs Adesão à Reciclagem', fontweight='bold')
axes[0].set_xlabel('Ocorrências em Encostas / Risco (%)', fontweight='bold')
axes[0].set_ylabel('Demanda por Coleta Seletiva (%)', fontweight='bold')
axes[0].legend(loc='upper right', frameon=True, fontsize=8.5)

# Gráfico B: Renda Média Domiciliar vs SLA Médio
for cid, cinfo in cluster_map.items():
    sub = bairros_df[bairros_df['cluster_id'] == cid]
    axes[1].scatter(
        sub['renda_media_domiciliar'], sub['sla_medio_horas'],
        color=cinfo['cor'], label=cinfo['nome'], s=120, edgecolors='black', alpha=0.85
    )
    for _, row in sub.iterrows():
        axes[1].annotate(
            row['bairro'], (row['renda_media_domiciliar'], row['sla_medio_horas']),
            xytext=(4, 3), textcoords='offset points', fontsize=8
        )

axes[1].set_title('Equidade de Atendimento: Renda vs Tempo de Resposta (SLA)', fontweight='bold')
axes[1].set_xlabel('Renda Média Domiciliar (R$)', fontweight='bold')
axes[1].set_ylabel('SLA Médio de Atendimento (horas)', fontweight='bold')
axes[1].legend(loc='upper right', frameon=True, fontsize=8.5)

fig.tight_layout()
fig_bairros = os.path.join(GRAFICOS_DIR, '04_distribuicao_bairros_clusters.png')
plt.savefig(fig_bairros)
plt.close()
print(f"Salvo: {fig_bairros}")

# 9. Salvar Dataset Enriquecido com os Clusters
colunas_export = [
    'id_bairro', 'bairro', 'prefeitura_bairro', 'populacao_bairro', 'area_km2',
    'total_chamados', 'densidade_chamados_hab', 'taxa_entulho_pct', 'taxa_seletiva_pct',
    'taxa_critica_encosta_pct', 'sla_medio_horas', 'renda_media_domiciliar',
    'cluster_id', 'cluster_codigo', 'cluster_nome'
]
bairros_df[colunas_export].to_csv(CSV_OUT, index=False)
print(f"\nDataset consolidado salvo em: {CSV_OUT}")

# 10. Relatório Resumido no Console
print("\n" + "=" * 70)
print("RESUMO EXECUTIVO DOS CLUSTERS MUNICIPAIS (SALVADOR - BA)")
print("=" * 70)
for cid, cinfo in cluster_map.items():
    sub = bairros_df[bairros_df['cluster_id'] == cid]
    bairros_nomes = sub['bairro'].tolist()
    print(f"\n🔹 {cinfo['nome']} ({len(sub)} bairros):")
    print(f"   Bairros: {', '.join(bairros_nomes)}")
    print(f"   População Coberta: {sub['populacao_bairro'].sum():,} habitantes")
    print(f"   Chamados 156 Totais: {sub['total_chamados'].sum():,} chamados")
    print(f"   Taxa Média Entulho: {sub['taxa_entulho_pct'].mean():.1f}%")
    print(f"   Taxa Média Encostas/Risco: {sub['taxa_critica_encosta_pct'].mean():.1f}%")
    print(f"   Demanda Coleta Seletiva: {sub['taxa_seletiva_pct'].mean():.2f}%")
    print(f"   SLA Médio de Atendimento: {sub['sla_medio_horas'].mean():.1f} horas ({sub['sla_medio_horas'].mean()/24:.1f} dias)")
    print(f"   Renda Média Domiciliar: R$ {sub['renda_media_domiciliar'].mean():.2f}")
    print(f"   Diretriz de Gestão: {cinfo['descricao']}")

print("\nPipeline de clusterização K-Means concluído com sucesso!")
