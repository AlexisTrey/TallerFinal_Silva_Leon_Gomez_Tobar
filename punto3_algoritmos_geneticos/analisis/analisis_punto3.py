"""
Analisis del Punto 3 (Algoritmos geneticos en videojuegos) - Grupo Silva Leon Tovar Gomez.

Lee los registros que generan los scripts silva_leon_tovar_gomez_escenarioA/B.lua
(carpeta ../datos) y produce:
  * ../figuras/convergencia_fitness.png      (fitness maximo y promedio vs generacion)
  * ../figuras/completaron_por_generacion.png (individuos que completan el nivel)
  * metricas_punto3.csv                       (tabla de metricas de la guia)
  * resumen en consola (tasas de mejora, estancamiento, generalizacion)

Uso:  python analisis_punto3.py
Requiere: pandas, matplotlib.
"""
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import pandas as pd  # noqa: E402

BASE = Path(__file__).resolve().parent.parent
DATOS = BASE / "datos"
FIGURAS = BASE / "figuras"
SALIDA = Path(__file__).resolve().parent

ESCENARIOS = {
    "A": {"nombre": "Escenario A: Yoshi's Island 1", "color": "#2a78d6"},
    "B": {"nombre": "Escenario B: Yoshi's Island 2", "color": "#eb6834"},
}
UMBRAL = 1000
POBLACION = 300
# Parametros de mutacion del script original (sin cambios)
PARAMETROS = {
    "MutateConnectionsChance": 0.25,
    "PerturbChance": 0.90,
    "CrossoverChance": 0.75,
    "LinkMutationChance": 2.0,
    "NodeMutationChance": 0.50,
    "BiasMutationChance": 0.40,
    "StepSize": 0.1,
    "DisableMutationChance": 0.4,
    "EnableMutationChance": 0.2,
}

TEXTO = "#0b0b0b"
TEXTO_2 = "#52514e"
GRILLA = "#e4e3df"


def cargar(e):
    carpeta = DATOS / f"escenario{e}"
    gen = pd.read_csv(carpeta / "generaciones.csv")
    eventos = pd.read_csv(carpeta / "eventos.csv")
    genomas = pd.read_csv(carpeta / "genomas.csv")
    return gen, eventos, genomas


def primer_evento(eventos, tipo):
    fila = eventos[eventos.evento == tipo]
    return None if fila.empty else fila.iloc[0]


def metricas(e):
    gen, eventos, genomas = cargar(e)
    ev1000 = primer_evento(eventos, "FITNESS_SUPERA_1000")
    evnivel = primer_evento(eventos, "NIVEL_COMPLETADO")
    evmeta = primer_evento(eventos, "META_DETECTADA")
    ultima = gen.iloc[-1]
    n = int(ultima.generacion)
    f_ini = float(gen.iloc[0].fitness_max_gen)
    f_fin = float(gen.fitness_max_historico.max())
    p_ini = float(gen.iloc[0].fitness_prom_gen)
    p_fin = float(ultima.fitness_prom_gen)
    gen_nivel = int(evnivel.generacion) if evnivel is not None else None
    f_nivel = float(gen[gen.generacion == gen_nivel].fitness_max_historico.iloc[0]) if gen_nivel else None
    return {
        "escenario": e,
        "generaciones_hasta_fitness_mayor_1000": int(ev1000.generacion) if ev1000 is not None else None,
        "minutos_hasta_fitness_mayor_1000": float(ev1000.tiempo_entrenamiento_min) if ev1000 is not None else None,
        "fitness_maximo": f_fin,
        "fitness_promedio_ultima_generacion": p_fin,
        "generaciones_totales": n,
        "tiempo_total_min": float(ultima.tiempo_acum_min),
        "generacion_nivel_completado": gen_nivel,
        "minutos_hasta_completar": float(evnivel.tiempo_entrenamiento_min) if evnivel is not None else None,
        "completo_nivel": "Si" if evnivel is not None else "No",
        "poblacion": POBLACION,
        "tasa_mutacion_conexiones_base": PARAMETROS["MutateConnectionsChance"],
        "tasa_mutacion_conexiones_final_prom": float(ultima.tasa_connections_prom),
        "fitness_inicial_gen1": f_ini,
        "tasa_mejora_max_total": (f_fin - f_ini) / n,
        "tasa_mejora_max_hasta_completar": (f_nivel - f_ini) / gen_nivel if gen_nivel else None,
        "tasa_mejora_promedio_total": (p_fin - p_ini) / n,
        "max_generaciones_sin_mejora": int(gen.gens_sin_mejora.max()),
        "individuos_evaluados": len(genomas),
        "individuos_que_completaron": int((genomas.completo_nivel == 1).sum()),
        "meta_x": int(evmeta.rightmost) if evmeta is not None else None,
    }


def estilo_ejes(ax):
    for lado in ("top", "right"):
        ax.spines[lado].set_visible(False)
    for lado in ("left", "bottom"):
        ax.spines[lado].set_color(TEXTO_2)
    ax.tick_params(colors=TEXTO_2, labelsize=9)
    ax.grid(axis="y", color=GRILLA, linewidth=0.8)
    ax.set_axisbelow(True)


def grafica_convergencia():
    fig, ax = plt.subplots(figsize=(7.2, 4.9), dpi=300)
    for e, cfg in ESCENARIOS.items():
        gen, eventos, _ = cargar(e)
        ax.plot(gen.generacion, gen.fitness_max_historico, color=cfg["color"], linewidth=2,
                label=f"{cfg['nombre']}: fitness máximo")
        ax.plot(gen.generacion, gen.fitness_prom_gen, color=cfg["color"], linewidth=1.4,
                linestyle=(0, (4, 2)), label=f"{cfg['nombre']}: fitness promedio")
        ev = primer_evento(eventos, "NIVEL_COMPLETADO")
        if ev is not None:
            g = int(ev.generacion)
            y = float(gen[gen.generacion == g].fitness_max_historico.iloc[0])
            ax.scatter([g], [y], s=60, color=cfg["color"], edgecolor="white", linewidth=1.5, zorder=5)
            ax.annotate(f"Completa el nivel (gen. {g})", xy=(g, y), xytext=(10, -12), textcoords="offset points",
                        ha="left", va="top", fontsize=8, color=TEXTO)
    ax.axhline(UMBRAL, color=TEXTO_2, linewidth=1, linestyle=(0, (1, 2)))
    ax.text(51, UMBRAL + 60, "Umbral: fitness = 1000", ha="right", va="bottom", fontsize=8, color=TEXTO_2)
    ax.set_xlabel("Generación", color=TEXTO, fontsize=10)
    ax.set_ylabel("Fitness", color=TEXTO, fontsize=10)
    ax.set_xlim(0, 52)
    ax.set_ylim(0, 5200)
    estilo_ejes(ax)
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.16), ncol=2, fontsize=7.5, frameon=False)
    fig.tight_layout()
    fig.savefig(FIGURAS / "convergencia_fitness.png", facecolor="white")
    plt.close(fig)


def grafica_completados():
    fig, ax = plt.subplots(figsize=(7.2, 3.0), dpi=300)
    ancho = 0.4
    for i, (e, cfg) in enumerate(ESCENARIOS.items()):
        gen, _, _ = cargar(e)
        x = gen.generacion + (i - 0.5) * ancho
        ax.bar(x, gen.completaron_nivel, width=ancho - 0.05, color=cfg["color"], label=cfg["nombre"])
    ax.set_xlabel("Generación", color=TEXTO, fontsize=10)
    ax.set_ylabel("Individuos que completan", color=TEXTO, fontsize=10)
    ax.set_xlim(0, 52)
    estilo_ejes(ax)
    ax.legend(loc="upper left", fontsize=8, frameon=False)
    fig.tight_layout()
    fig.savefig(FIGURAS / "completaron_por_generacion.png", facecolor="white")
    plt.close(fig)


def main():
    FIGURAS.mkdir(exist_ok=True)
    tabla = pd.DataFrame([metricas(e) for e in ESCENARIOS])
    tabla.to_csv(SALIDA / "metricas_punto3.csv", index=False)
    grafica_convergencia()
    grafica_completados()

    pd.set_option("display.width", 200)
    print(tabla.set_index("escenario").T.to_string())
    gen_csv = DATOS / "generalizacion" / "generalizacion.csv"
    if gen_csv.exists():
        g = pd.read_csv(gen_csv).iloc[0]
        print(f"\nGeneralizacion A->B: fitness en A {g.fitness_en_A}, fitness en B {g.fitness_en_B}, "
              f"X alcanzada {g.rightmost}, completo {g.completo_nivel}")
    print("\nFiguras guardadas en", FIGURAS)


if __name__ == "__main__":
    main()
