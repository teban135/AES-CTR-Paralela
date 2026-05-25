# Genera un archivo de ~1 GB repitiendo una frase
frase = "Este es un texto de prueba para generar un archivo de gran tamaño en formato TXT.\n"
bytes_objetivo = 1073741824  # 1 GB en bytes

with open("archivo_texto_real.txt", "w", encoding="utf-8") as f:
    escrito = 0
    while escrito < bytes_objetivo:
        f.write(frase)
        escrito += len(frase.encode('utf-8'))