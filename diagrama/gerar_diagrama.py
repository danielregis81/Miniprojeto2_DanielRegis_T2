# -*- coding: utf-8 -*-
"""
Gera o diagrama do modelo estrela do case Pata Amiga (PNG).
Requisitos do enunciado (secao 3):
  1) fato_pedido no centro, com o grao "1 linha = 1 pedido"
  2) dimensoes em volta: dim_tempo, dim_loja, dim_categoria
  3) dim_tempo ligada DUAS vezes (pedido e entrega) = role-playing
  4) dim_praca ligada a dim_loja via bridge_loja_praca (caminho indireto)
"""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

VERDE = "#2E7D32"
VERDE_CLARO = "#A5D6A7"
AZUL = "#1565C0"
AZUL_CLARO = "#90CAF9"
LARANJA = "#EF6C00"
LARANJA_CLARO = "#FFCC80"
CINZA = "#546E7A"
CINZA_CLARO = "#CFD8DC"

fig, ax = plt.subplots(figsize=(13, 9.6))
ax.set_xlim(0, 13)
ax.set_ylim(0, 9.6)
ax.axis("off")


def caixa(x, y, w, h, titulo, linhas, cor_borda, cor_fundo, titulo_cor="white"):
    box = FancyBboxPatch(
        (x, y), w, h,
        boxstyle="round,pad=0.02,rounding_size=0.12",
        linewidth=2, edgecolor=cor_borda, facecolor=cor_fundo, zorder=3,
    )
    ax.add_patch(box)
    # faixa do titulo
    faixa = FancyBboxPatch(
        (x, y + h - 0.55), w, 0.55,
        boxstyle="round,pad=0.02,rounding_size=0.12",
        linewidth=0, facecolor=cor_borda, zorder=4,
    )
    ax.add_patch(faixa)
    ax.text(x + w / 2, y + h - 0.28, titulo, ha="center", va="center",
            fontsize=10.5, fontweight="bold", color=titulo_cor, zorder=5)
    ax.text(x + 0.15, y + h - 0.75, linhas, ha="left", va="top",
            fontsize=8.2, color="#212121", zorder=5, linespacing=1.4)


def seta(p1, p2, cor, texto=None, estilo="-", off=(0, 0)):
    arr = FancyArrowPatch(
        p1, p2, arrowstyle="-", linewidth=1.8, color=cor,
        linestyle=estilo, zorder=1, mutation_scale=12,
    )
    ax.add_patch(arr)
    if texto:
        mx = (p1[0] + p2[0]) / 2 + off[0]
        my = (p1[1] + p2[1]) / 2 + off[1]
        ax.text(mx, my, texto, ha="center", va="center", fontsize=7.5,
                style="italic", color=cor,
                bbox=dict(boxstyle="round,pad=0.2", fc="white", ec="none", alpha=0.85),
                zorder=6)


# ---- FATO no centro ----
fx, fy, fw, fh = 4.7, 3.5, 3.6, 2.3
caixa(fx, fy, fw, fh, "fato_pedido",
      "PK  sk_pedido\n     numero_pedido (deg.)\nFK  sk_tempo_pedido\nFK  sk_tempo_entrega\nFK  sk_loja\nFK  sk_categoria\n--- metricas ---\n     qt_itens\n     vl_liquido\n     5 x dias_*",
      VERDE, "#E8F5E9")
ax.text(fx + fw / 2, fy - 0.35, 'grao: "1 linha = 1 pedido"  (4.044 linhas)',
        ha="center", va="center", fontsize=9, fontweight="bold", color=VERDE)

# ---- DIM_TEMPO (topo, role-playing: 2 ligacoes) ----
tx, ty, tw, th = 4.9, 6.9, 3.2, 1.7
caixa(tx, ty, tw, th, "dim_tempo",
      "PK  sk_tempo (AAAAMMDD)\n     data, ano, mes\n     role-playing: 2 papeis",
      AZUL, "#E3F2FD")

# ---- DIM_LOJA (esquerda) ----
lx, ly, lw, lh = 0.3, 4.2, 3.2, 1.9
caixa(lx, ly, lw, lh, "dim_loja",
      "PK  sk_loja\n     cod_loja (natural)\n     chave_loja, porte\n     populacao_cidade\n     faixa_franquia",
      LARANJA, "#FFF3E0")

# ---- DIM_CATEGORIA (direita) ----
cx, cy, cw, ch = 9.5, 4.2, 3.2, 1.9
caixa(cx, cy, cw, ch, "dim_categoria",
      "PK  sk_categoria\n     categoria_origem\n     (grafia crua)\n     nome_categoria\n     grupo_categoria",
      LARANJA, "#FFF3E0")

# ---- BRIDGE (baixo-esquerda) ----
bx, by, bw, bh = 0.9, 0.6, 3.0, 1.6
caixa(bx, by, bw, bh, "bridge_loja_praca",
      "PK  cod_loja + sk_praca\nFK  sk_praca\n     fator_publico\n     (rateio N:N)",
      CINZA, "#ECEFF1")

# ---- DIM_PRACA (baixo-direita) ----
px, py, pw, ph = 9.3, 0.6, 3.2, 1.6
caixa(px, py, pw, ph, "dim_praca",
      "PK  sk_praca\n     cod_praca\n     nome_praca, regional\n     domicilios_com_pet",
      CINZA, "#ECEFF1")

# ===== LIGACOES =====
fato_topo = (fx + fw / 2, fy + fh)
fato_esq = (fx, fy + fh / 2)
fato_dir = (fx + fw, fy + fh / 2)

# dim_tempo ligada DUAS vezes (role-playing)
seta((tx + tw * 0.35, ty), (fato_topo[0] - 0.5, fato_topo[1]), AZUL,
     "sk_tempo_pedido", off=(-0.9, 0.15))
seta((tx + tw * 0.65, ty), (fato_topo[0] + 0.5, fato_topo[1]), AZUL,
     "sk_tempo_entrega", off=(1.0, -0.15))

# dim_loja -> fato
seta((lx + lw, ly + lh / 2), fato_esq, LARANJA, "sk_loja", off=(0, 0.2))

# dim_categoria -> fato
seta((cx, cy + ch / 2), fato_dir, LARANJA, "sk_categoria", off=(0, 0.2))

# dim_loja -> bridge -> dim_praca (caminho INDIRETO, tracejado)
seta((lx + lw * 0.4, ly), (bx + bw * 0.6, by + bh), CINZA, "cod_loja",
     estilo="--", off=(-0.75, 0))
seta((bx + bw, by + bh / 2), (px, py + ph / 2), CINZA, "sk_praca",
     estilo="--", off=(0, 0.2))

# titulo
ax.text(6.5, 9.4, "Modelo Estrela - Pata Amiga (dw_pata_amiga)",
        ha="center", va="center", fontsize=14, fontweight="bold", color=VERDE)
ax.text(6.5, 9.08, "1 fato  |  4 dimensoes (dim_tempo em 2 papeis)  |  1 bridge N:N",
        ha="center", va="center", fontsize=9.5, color="#555")

# legenda do caminho indireto
ax.text(2.4, 2.45, "caminho indireto (a unica ligacao\nque nao vai direto a fato)",
        ha="center", va="center", fontsize=7.5, style="italic", color=CINZA)

plt.tight_layout()
out = "modelo_estrela.png"
plt.savefig(out, dpi=150, bbox_inches="tight", facecolor="white")
print("Diagrama salvo em", out)
