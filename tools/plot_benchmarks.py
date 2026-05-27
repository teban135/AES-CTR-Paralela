#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import json
import sys

def generate_plots():
    try:
        import matplotlib.pyplot as plt
        import numpy as np
    except ImportError:
        print("[-] Advertencia: Las librerías 'matplotlib' o 'numpy' no están instaladas.")
        print("    No se pudieron generar los gráficos estáticos PNG de forma automática.")
        return False

    json_path = os.path.join("data", "output", "benchmark_1gb_results.json")
    if not os.path.exists(json_path):
        print(f"[-] Error: No se encontró el archivo de resultados {json_path}")
        return False

    with open(json_path, "r", encoding="utf-8-sig") as f:
        data = json.load(f)

    results = data["Results"]
    
    # Extraer métricas
    methods = [r["Metodo"] for r in results]
    tput_total = [r["CifradoTputTotal"] for r in results]
    tput_neto = [r["CifradoTputNeto"] for r in results]
    speedup_total = [r["SpeedupTotal"] for r in results]
    speedup_neto = [r["SpeedupNeto"] for r in results]

    # Configuración de estilo global - Modo Oscuro de Alta Tecnología (Tema Cyberpunk/Neon)
    plt.style.use('dark_background')
    plt.rcParams['font.family'] = 'sans-serif'
    plt.rcParams['font.sans-serif'] = ['Segoe UI', 'DejaVu Sans', 'Arial']
    plt.rcParams['grid.color'] = '#1A1D24'
    plt.rcParams['grid.alpha'] = 0.8
    plt.rcParams['axes.facecolor'] = '#07080B'
    plt.rcParams['figure.facecolor'] = '#07080B'

    # -------------------------------------------------------------
    # GRÁFICO 1: THROUGHPUT (MB/s) - Comparación Total vs Neto
    # -------------------------------------------------------------
    fig, ax = plt.subplots(figsize=(10, 6), dpi=150)
    x = np.arange(len(methods))
    width = 0.35

    # Efecto de neón: Relleno translúcido (alpha=0.5) con bordes ultrabrillantes de grosor 2.5
    rects1 = ax.bar(x - width/2, tput_total, width, label='Throughput Total (con E/S)', 
                    color='#D000FF', edgecolor='#D000FF', linewidth=2.5, alpha=0.5)
    rects2 = ax.bar(x + width/2, tput_neto, width, label='Throughput Neto (Cómputo)', 
                    color='#00FFFF', edgecolor='#00FFFF', linewidth=2.5, alpha=0.5)

    ax.set_ylabel('Rendimiento (MB/s)', fontsize=12, fontweight='bold', labelpad=12, color='#F5F7FA')
    ax.set_title('AES-CTR 1.01 GB: Rendimiento Comparativo (Throughput)', fontsize=14, fontweight='bold', pad=22, color='#FFFFFF')
    ax.set_xticks(x)
    ax.set_xticklabels(methods, fontsize=11, fontweight='bold', color='#E0E0E0')
    ax.legend(frameon=True, facecolor='#12131C', edgecolor='#1B2234', fontsize=10, labelcolor='#F5F7FA')
    ax.grid(True, linestyle=':', axis='y', color='#1B2234', alpha=0.6)

    # Añadir etiquetas de texto sobre las barras con realce de color
    def autolabel(rects, is_net):
        for rect in rects:
            height = rect.get_height()
            if height > 0:
                if height >= 1024:
                    label_text = f"{height/1024:.2f} GB/s"
                else:
                    label_text = f"{height:.1f} MB/s"
                
                # Color del texto correspondiente a su barra neón
                text_color = '#00FFFF' if is_net else '#D000FF'
                
                ax.annotate(label_text,
                            xy=(rect.get_x() + rect.get_width() / 2, height),
                            xytext=(0, 6),  # Desplazamiento vertical
                            textcoords="offset points",
                            ha='center', va='bottom', fontsize=9, fontweight='bold', color=text_color)

    autolabel(rects1, False)
    autolabel(rects2, True)

    # Quitar bordes innecesarios para diseño limpio
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_color('#1B2234')
    ax.spines['bottom'].set_color('#1B2234')
    
    # Escala logarítmica para manejar la tremenda disparidad de la GPU
    ax.set_yscale('log')
    ax.set_ylabel('Throughput (MB/s) - Escala Logarítmica', fontsize=12, fontweight='bold', labelpad=12, color='#F5F7FA')

    # Guardar gráfico de Throughput
    output_tput = os.path.join("data", "output", "throughput_comparison.png")
    plt.tight_layout()
    plt.savefig(output_tput, bbox_inches='tight', facecolor='#07080B')
    plt.close()
    print(f"[+] Gráfico de Throughput neón generado exitosamente en: {output_tput}")

    # -------------------------------------------------------------
    # GRÁFICO 2: SPEEDUP - Factor de Aceleración CPU vs GPU
    # -------------------------------------------------------------
    fig, ax = plt.subplots(figsize=(10, 6), dpi=150)
    
    # Efecto neón en speedup: Magenta neón vs Verde Lima neón
    rects_total = ax.bar(x - width/2, speedup_total, width, label='Speedup Total (con E/S)', 
                         color='#FF007F', edgecolor='#FF007F', linewidth=2.5, alpha=0.5)
    rects_neto = ax.bar(x + width/2, speedup_neto, width, label='Speedup Neto (Cómputo)', 
                        color='#39FF14', edgecolor='#39FF14', linewidth=2.5, alpha=0.5)

    ax.set_ylabel('Factor de Aceleración (X veces más rápido)', fontsize=12, fontweight='bold', labelpad=12, color='#F5F7FA')
    ax.set_title('AES-CTR 1.01 GB: Aceleración Comparativa (Speedup vs Secuencial)', fontsize=14, fontweight='bold', pad=22, color='#FFFFFF')
    ax.set_xticks(x)
    ax.set_xticklabels(methods, fontsize=11, fontweight='bold', color='#E0E0E0')
    ax.legend(frameon=True, facecolor='#12131C', edgecolor='#1B2234', fontsize=10, labelcolor='#F5F7FA')
    ax.grid(True, linestyle=':', axis='y', color='#1B2234', alpha=0.6)

    # Añadir etiquetas con color de neón correspondiente
    def autolabel_speedup(rects, is_net):
        for rect in rects:
            height = rect.get_height()
            if height > 0:
                text_color = '#39FF14' if is_net else '#FF007F'
                ax.annotate(f"{height:.2f}x",
                            xy=(rect.get_x() + rect.get_width() / 2, height),
                            xytext=(0, 6),
                            textcoords="offset points",
                            ha='center', va='bottom', fontsize=9, fontweight='bold', color=text_color)

    autolabel_speedup(rects_total, False)
    autolabel_speedup(rects_neto, True)

    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_color('#1B2234')
    ax.spines['bottom'].set_color('#1B2234')
    
    # Escala logarítmica debido al speedup masivo de GPU neto (~245.9x)
    if max(speedup_neto) > 50:
        ax.set_yscale('log')
        ax.set_ylabel('Aceleración (Speedup) - Escala Logarítmica', fontsize=12, fontweight='bold', labelpad=12, color='#F5F7FA')

    # Guardar gráfico de Speedup
    output_speedup = os.path.join("data", "output", "speedup_comparison.png")
    plt.tight_layout()
    plt.savefig(output_speedup, bbox_inches='tight', facecolor='#07080B')
    plt.close()
    print(f"[+] Gráfico de Speedup neón generado exitosamente en: {output_speedup}")
    
    return True

if __name__ == "__main__":
    generate_plots()
