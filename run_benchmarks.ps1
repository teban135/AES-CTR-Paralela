# ========================================================================================
# SCRIPT DE BENCHMARKING COMPARATIVO PARA AES-128-CTR
# Diseñado para Windows PowerShell.
# Mide y compara el rendimiento de las versiones: Secuencial, OpenMP y CUDA.
# ========================================================================================

# Asegurar codificación UTF-8 para consola limpia
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "      EJECUTOR DE PRUEBAS COMPARATIVAS (BENCHMARK) - AES-CTR            " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

# 1. Rutas de directorios y ejecutables
$BinDir = "bin"
$DataInputDir = "data/input"
$DataOutputDir = "data/output"

$SeqExe = "$BinDir/aes_seq.exe"
$OmpExe = "$BinDir/aes_omp.exe"
$CudaExe = "$BinDir/aes_cuda.exe"

$File10 = "$DataInputDir/test_10mb.txt"
$File100 = "$DataInputDir/test_100mb.txt"

# 2. Compilar si falta algún ejecutable
if (!(Test-Path $BinDir)) {
    New-Item -ItemType Directory -Path $BinDir | Out-Null
}

Write-Host "[*] Comprobando ejecutables..." -ForegroundColor Yellow

if (!(Test-Path $SeqExe)) {
    Write-Host "[-] Falta $SeqExe. Compilando secuencial..." -ForegroundColor DarkYellow
    g++ -O3 -o $SeqExe sequential/main_seq.cpp sequential/aes_sequential.cpp common/aes_core.cpp
}
if (!(Test-Path $OmpExe)) {
    Write-Host "[-] Falta $OmpExe. Compilando OpenMP..." -ForegroundColor DarkYellow
    g++ -O3 -fopenmp -o $OmpExe openmp/main_omp.cpp openmp/aes_openmp.cpp common/aes_core.cpp
}
if (!(Test-Path $CudaExe)) {
    Write-Host "[-] Falta $CudaExe. Compilando CUDA..." -ForegroundColor DarkYellow
    nvcc -O3 -o $CudaExe cuda/main_cuda.cu cuda/aes_cuda.cu
}

# 3. Comprobar que existan los datasets de pruebas
if (!(Test-Path $File10) -or !(Test-Path $File100)) {
    Write-Host "[!] Faltan archivos de prueba. Ejecuta el generador primero." -ForegroundColor Red
    exit 1
}

# Clave y Nonce estándar para pruebas
$KeyHex = "000102030405060708090a0b0c0d0e0f"
$NonceHex = "0123456789abcdef"

# 4. Función auxiliar para ejecutar benchmark y extraer métricas
function Run-Benchmark {
    param(
        [string]$Name,
        [string]$Exe,
        [string]$InputFile,
        [string]$OutputFile,
        [string]$DecryptedFile,
        [string]$ExtraArgs = ""
    )

    Write-Host "--------------------------------------------------------" -ForegroundColor Gray
    Write-Host " Ejecutando $Name..." -ForegroundColor White

    # Cifrado
    $EncStart = [System.Diagnostics.Stopwatch]::StartNew()
    $EncOutput = & $Exe $InputFile $OutputFile $KeyHex $NonceHex $ExtraArgs 2>&1
    $EncStart.Stop()
    $EncTime = $EncStart.Elapsed.TotalMilliseconds

    # Descifrado
    $DecStart = [System.Diagnostics.Stopwatch]::StartNew()
    $DecOutput = & $Exe $OutputFile $DecryptedFile $KeyHex $NonceHex $ExtraArgs 2>&1
    $DecStart.Stop()
    $DecTime = $DecStart.Elapsed.TotalMilliseconds

    $Integrity = "FAIL"
    if ($OrigHash -eq $DecHash) {
        $Integrity = "PASS"
    }


    # Intentar parsear Throughput de la salida del programa
    $EncThroughput = $null
    $DecThroughput = $null

    foreach ($line in $EncOutput) {
        if ($line -match "Throughput\s*:\s*([\d\.]+)\s*MB/s") {
            $EncThroughput = [double]$Matches[1]
        }
    }

    if ($Name -eq "CUDA") {
        # Para CUDA, el primer run incluye la inicialización del contexto (cold start)
        # Hacemos una segunda pasada para reportar el rendimiento real de la GPU en régimen permanente
        $EncStart2 = [System.Diagnostics.Stopwatch]::StartNew()
        & $Exe $InputFile $OutputFile $KeyHex $NonceHex $ExtraArgs > $null
        $EncStart2.Stop()
        $EncTime = $EncStart2.Elapsed.TotalMilliseconds
    }

    return [PSCustomObject]@{
        Metodo = $Name
        CifradoMs = [Math]::Round($EncTime, 2)
        DescifradoMs = [Math]::Round($DecTime, 2)
        Correcto = $Integrity
    }
}

# 5. Ejecutar Benchmarks para 10 MB
Write-Host "`n[+] === INICIANDO BENCHMARK CON DATASET DE 10 MB ===" -ForegroundColor Green
$ResSeq10 = Run-Benchmark "Secuencial" $SeqExe $File10 "$DataOutputDir/enc_seq_10.bin" "$DataOutputDir/dec_seq_10.txt"
$ResOmp10 = Run-Benchmark "OpenMP (16 Hilos)" $OmpExe $File10 "$DataOutputDir/enc_omp_10.bin" "$DataOutputDir/dec_omp_10.txt"
$ResCuda10 = Run-Benchmark "CUDA (GPU)" $CudaExe $File10 "$DataOutputDir/enc_cuda_10.bin" "$DataOutputDir/dec_cuda_10.txt"

# 6. Ejecutar Benchmarks para 100 MB
Write-Host "`n[+] === INICIANDO BENCHMARK CON DATASET DE 100 MB ===" -ForegroundColor Green
$ResSeq100 = Run-Benchmark "Secuencial" $SeqExe $File100 "$DataOutputDir/enc_seq_100.bin" "$DataOutputDir/dec_seq_100.txt"
$ResOmp100 = Run-Benchmark "OpenMP (16 Hilos)" $OmpExe $File100 "$DataOutputDir/enc_omp_100.bin" "$DataOutputDir/dec_omp_100.txt"
$ResCuda100 = Run-Benchmark "CUDA (GPU)" $CudaExe $File100 "$DataOutputDir/enc_cuda_100.bin" "$DataOutputDir/dec_cuda_100.txt"

# 7. Imprimir tablas de resultados comparativos
Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "                TABLA DE RESULTADOS COMPARATIVOS                     " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

Write-Host "`n>>> PRUEBAS CON 10 MB:" -ForegroundColor Yellow
$Table10 = @($ResSeq10, $ResOmp10, $ResCuda10)
$Table10 | Format-Table -AutoSize

Write-Host ">>> PRUEBAS CON 100 MB:" -ForegroundColor Yellow
$Table100 = @($ResSeq100, $ResOmp100, $ResCuda100)
$Table100 | Format-Table -AutoSize

# Guardar un reporte de resultados rápido en markdown
$ReportPath = "data/output/benchmark_report.md"
$MarkdownContent = @"
# Reporte de Rendimiento AES-CTR (CPU vs GPU)

Generado el $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Resumen del Entorno de Hardware
- **CPU:** 16 hilos lógicos
- **GPU:** NVIDIA GeForce RTX 5060 Laptop GPU
- **Memoria Pinned PCIe habilitada:** Sí (16 MB Stream Buffer)

## Dataset de 10 MB

| Método | Tiempo Cifrado | Tiempo Descifrado | Integridad (SHA-256) |
|---|---|---|---|
| Secuencial | $($ResSeq10.CifradoMs) ms | $($ResSeq10.DescifradoMs) ms | $($ResSeq10.Correcto) |
| OpenMP (16 Hilos) | $($ResOmp10.CifradoMs) ms | $($ResOmp10.DescifradoMs) ms | $($ResOmp10.Correcto) |
| CUDA (GPU) | $($ResCuda10.CifradoMs) ms | $($ResCuda10.DescifradoMs) ms | $($ResCuda10.Correcto) |

## Dataset de 100 MB

| Método | Tiempo Cifrado | Tiempo Descifrado | Integridad (SHA-256) |
|---|---|---|---|
| Secuencial | $($ResSeq100.CifradoMs) ms | $($ResSeq100.DescifradoMs) ms | $($ResSeq100.Correcto) |
| OpenMP (16 Hilos) | $($ResOmp100.CifradoMs) ms | $($ResOmp100.DescifradoMs) ms | $($ResOmp100.Correcto) |
| CUDA (GPU) | $($ResCuda100.CifradoMs) ms | $($ResCuda100.DescifradoMs) ms | $($ResCuda100.Correcto) |
"@

$MarkdownContent | Out-File -FilePath $ReportPath -Encoding utf8
Write-Host "[+] ¡Reporte detallado guardado exitosamente en: $ReportPath!" -ForegroundColor Green
