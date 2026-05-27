# ========================================================================================
# SCRIPT DE BENCHMARKING DE ALTO RENDIMIENTO PARA AES-128-CTR (1.01 GB)
# Diseñado para medir Secuencial (SSE2), OpenMP y CUDA en el archivo archivo_texto_real.txt
# ========================================================================================

$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "         EJECUTOR DE BENCHMARK PARA ARCHIVO DE 1.01 GB (AES-CTR)      " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$BinDir = "bin"
$DataInputDir = "data/input"
$DataOutputDir = "data/output"

$SeqExe = "$BinDir/aes_seq.exe"
$OmpExe = "$BinDir/aes_omp.exe"
$CudaExe = "$BinDir/aes_cuda.exe"
$InputFile = "$DataInputDir/archivo_texto_real.txt"

# Clave y Nonce estándar
$KeyHex = "000102030405060708090a0b0c0d0e0f"
$NonceHex = "0123456789abcdef"

# 1. Validar que exista el archivo de 1GB
if (!(Test-Path $InputFile)) {
    Write-Host "[-] ERROR: No se encontró el archivo $InputFile." -ForegroundColor Red
    Write-Host "[-] Ejecuta el script de generación o asegúrate de que el archivo esté en data/input/." -ForegroundColor Red
    exit 1
}

$FileSizeMB = [Math]::Round((Get-Item $InputFile).Length / (1024 * 1024), 2)
Write-Host "[*] Archivo de entrada detectado: $InputFile ($FileSizeMB MB)" -ForegroundColor Yellow

# Calcular Hash SHA-256 Original
Write-Host "[*] Calculando Hash SHA-256 original (esto puede tomar unos segundos)..." -ForegroundColor Yellow
$OrigHashStart = [System.Diagnostics.Stopwatch]::StartNew()
$OrigHash = (Get-FileHash -Path $InputFile -Algorithm SHA256).Hash
$OrigHashStart.Stop()
Write-Host "[+] Hash SHA-256 Original: $OrigHash (Calculado en $($OrigHashStart.Elapsed.TotalSeconds) s)" -ForegroundColor Green

# 2. Función para ejecutar y extraer métricas
function Run-Execution {
    param(
        [string]$Name,
        [string]$Exe,
        [string]$InputPath,
        [string]$OutputPath,
        [string]$DecryptedPath,
        [string]$ExtraArgs = ""
    )

    Write-Host "`n----------------------------------------------------------------------" -ForegroundColor Gray
    Write-Host " [*] Ejecutando $Name..." -ForegroundColor White

    # Cifrado
    Write-Host "     -> Cifrando..." -ForegroundColor DarkGray
    $EncOutput = & $Exe $InputPath $OutputPath $KeyHex $NonceHex $ExtraArgs 2>&1
    
    # Parsear métricas de cifrado
    $CifradoTotalMs = 0.0
    $CifradoNetoMs = 0.0
    $CifradoTputTotal = 0.0
    $CifradoTputNeto = 0.0

    foreach ($line in $EncOutput) {
        # Mostrar salida para depuración
        Write-Host "        $line" -ForegroundColor DarkGray
        
        if ($line -match "Tiempo total\s*:\s*([\d\.]+)\s*ms") {
            $CifradoTotalMs = [double]$Matches[1]
        }
        elseif ($line -match "Tiempo total \(E/S\)\s*:\s*([\d\.]+)\s*ms") {
            $CifradoTotalMs = [double]$Matches[1]
        }
        
        if ($line -match "Tiempo de CPU Neto\s*:\s*([\d\.]+)\s*ms") {
            $CifradoNetoMs = [double]$Matches[1]
        }
        elseif ($line -match "Tiempo de GPU Neto\s*:\s*([\d\.]+)\s*ms") {
            $CifradoNetoMs = [double]$Matches[1]
        }
        
        if ($line -match "Throughput\s*:\s*([\d\.]+)\s*MB/s") {
            $CifradoTputTotal = [double]$Matches[1]
        }
        elseif ($line -match "Throughput \(E/S\)\s*:\s*([\d\.]+)\s*MB/s") {
            $CifradoTputTotal = [double]$Matches[1]
        }
        
        if ($line -match "Throughput CPU Neto\s*:\s*([\d\.]+)\s*MB/s") {
            $CifradoTputNeto = [double]$Matches[1]
        }
        elseif ($line -match "Throughput GPU Neto\s*:\s*([\d\.]+)\s*MB/s") {
            $CifradoTputNeto = [double]$Matches[1]
        }
    }

    # Descifrado
    Write-Host "     -> Descifrando..." -ForegroundColor DarkGray
    $DecOutput = & $Exe $OutputPath $DecryptedPath $KeyHex $NonceHex $ExtraArgs 2>&1
    
    # Parsear métricas de descifrado
    $DescifradoTotalMs = 0.0
    $DescifradoNetoMs = 0.0
    $DescifradoTputTotal = 0.0
    $DescifradoTputNeto = 0.0

    foreach ($line in $DecOutput) {
        if ($line -match "Tiempo total\s*:\s*([\d\.]+)\s*ms") {
            $DescifradoTotalMs = [double]$Matches[1]
        }
        elseif ($line -match "Tiempo total \(E/S\)\s*:\s*([\d\.]+)\s*ms") {
            $DescifradoTotalMs = [double]$Matches[1]
        }
        
        if ($line -match "Tiempo de CPU Neto\s*:\s*([\d\.]+)\s*ms") {
            $DescifradoNetoMs = [double]$Matches[1]
        }
        elseif ($line -match "Tiempo de GPU Neto\s*:\s*([\d\.]+)\s*ms") {
            $DescifradoNetoMs = [double]$Matches[1]
        }
        
        if ($line -match "Throughput\s*:\s*([\d\.]+)\s*MB/s") {
            $DescifradoTputTotal = [double]$Matches[1]
        }
        elseif ($line -match "Throughput \(E/S\)\s*:\s*([\d\.]+)\s*MB/s") {
            $DescifradoTputTotal = [double]$Matches[1]
        }
        
        if ($line -match "Throughput CPU Neto\s*:\s*([\d\.]+)\s*MB/s") {
            $DescifradoTputNeto = [double]$Matches[1]
        }
        elseif ($line -match "Throughput GPU Neto\s*:\s*([\d\.]+)\s*MB/s") {
            $DescifradoTputNeto = [double]$Matches[1]
        }
    }

    # Si es secuencial, el tiempo neto es igual al total
    if ($Name -eq "Secuencial") {
        $CifradoNetoMs = $CifradoTotalMs
        $CifradoTputNeto = $CifradoTputTotal
        $DescifradoNetoMs = $DescifradoTotalMs
        $DescifradoTputNeto = $DescifradoTputTotal
    }

    # Verificar Integridad Real
    Write-Host "     -> Verificando Integridad SHA-256..." -ForegroundColor DarkGray
    $DecHash = (Get-FileHash -Path $DecryptedPath -Algorithm SHA256).Hash
    
    $Integrity = "FAIL"
    if ($OrigHash -eq $DecHash) {
        $Integrity = "PASS"
        Write-Host "     [+] ¡INTEGRIDAD CORRECTA! (SHA-256 Coincide)" -ForegroundColor Green
    } else {
        Write-Host "     [-] ¡ERROR DE INTEGRIDAD! Los archivos difieren." -ForegroundColor Red
    }

    return [PSCustomObject]@{
        Metodo = $Name
        CifradoTotalMs = $CifradoTotalMs
        CifradoNetoMs = $CifradoNetoMs
        CifradoTputTotal = $CifradoTputTotal
        CifradoTputNeto = $CifradoTputNeto
        DescifradoTotalMs = $DescifradoTotalMs
        DescifradoNetoMs = $DescifradoNetoMs
        DescifradoTputTotal = $DescifradoTputTotal
        DescifradoTputNeto = $DescifradoTputNeto
        Integridad = $Integrity
    }
}

# 3. Ejecutar los benchmarks
Write-Host "`n[+] === INICIANDO BENCHMARKS ===" -ForegroundColor Green

$ResSeq = Run-Execution "Secuencial" $SeqExe $InputFile "$DataOutputDir/encrypted_seq.bin" "$DataOutputDir/decrypted_seq.txt"
$ResOmp = Run-Execution "OpenMP (16 Hilos)" $OmpExe $InputFile "$DataOutputDir/encrypted_omp.bin" "$DataOutputDir/decrypted_omp.txt" "16"
$ResCuda = Run-Execution "CUDA (GPU)" $CudaExe $InputFile "$DataOutputDir/encrypted_cuda.bin" "$DataOutputDir/decrypted_cuda.txt"

# Calcular Speedups (basado en Cifrado)
$SpeedupOmpTotal = [Math]::Round($ResSeq.CifradoTotalMs / $ResOmp.CifradoTotalMs, 2)
$SpeedupOmpNeto = [Math]::Round($ResSeq.CifradoNetoMs / $ResOmp.CifradoNetoMs, 2)
$SpeedupCudaTotal = [Math]::Round($ResSeq.CifradoTotalMs / $ResCuda.CifradoTotalMs, 2)
$SpeedupCudaNeto = [Math]::Round($ResSeq.CifradoNetoMs / $ResCuda.CifradoNetoMs, 2)

# 4. Imprimir resultados comparativos en consola
Write-Host "`n======================================================================" -ForegroundColor Cyan
Write-Host "           RESULTADOS DE RENDIMIENTO CON ARCHIVO DE 1.01 GB           " -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan

$ResultsTable = @(
    [PSCustomObject]@{
        Metodo = "Secuencial"
        "T. Total (ms)" = $ResSeq.CifradoTotalMs
        "T. Neto (ms)" = $ResSeq.CifradoNetoMs
        "Tput Total (MB/s)" = $ResSeq.CifradoTputTotal
        "Tput Neto (MB/s)" = $ResSeq.CifradoTputNeto
        "Speedup Total" = "1.00x"
        "Speedup Neto" = "1.00x"
        Integridad = $ResSeq.Integridad
    },
    [PSCustomObject]@{
        Metodo = "OpenMP (16 H)"
        "T. Total (ms)" = $ResOmp.CifradoTotalMs
        "T. Neto (ms)" = $ResOmp.CifradoNetoMs
        "Tput Total (MB/s)" = $ResOmp.CifradoTputTotal
        "Tput Neto (MB/s)" = $ResOmp.CifradoTputNeto
        "Speedup Total" = "$($SpeedupOmpTotal)x"
        "Speedup Neto" = "$($SpeedupOmpNeto)x"
        Integridad = $ResOmp.Integridad
    },
    [PSCustomObject]@{
        Metodo = "CUDA (GPU)"
        "T. Total (ms)" = $ResCuda.CifradoTotalMs
        "T. Neto (ms)" = $ResCuda.CifradoNetoMs
        "Tput Total (MB/s)" = $ResCuda.CifradoTputTotal
        "Tput Neto (MB/s)" = $ResCuda.CifradoTputNeto
        "Speedup Total" = "$($SpeedupCudaTotal)x"
        "Speedup Neto" = "$($SpeedupCudaNeto)x"
        Integridad = $ResCuda.Integridad
    }
)

$ResultsTable | Format-Table -AutoSize

# 5. Guardar resultados en formato JSON para que Python los lea
$JSONPath = "$DataOutputDir/benchmark_1gb_results.json"
$JSONData = @{
    FileSizeMB = $FileSizeMB
    Hardware = @{
        CPU = "16 hilos lógicos"
        GPU = "NVIDIA GeForce RTX 5060 Laptop GPU"
    }
    Results = @(
        @{
            Metodo = "Secuencial"
            CifradoTotalMs = $ResSeq.CifradoTotalMs
            CifradoNetoMs = $ResSeq.CifradoNetoMs
            CifradoTputTotal = $ResSeq.CifradoTputTotal
            CifradoTputNeto = $ResSeq.CifradoTputNeto
            SpeedupTotal = 1.0
            SpeedupNeto = 1.0
            Integridad = $ResSeq.Integridad
        },
        @{
            Metodo = "OpenMP"
            CifradoTotalMs = $ResOmp.CifradoTotalMs
            CifradoNetoMs = $ResOmp.CifradoNetoMs
            CifradoTputTotal = $ResOmp.CifradoTputTotal
            CifradoTputNeto = $ResOmp.CifradoTputNeto
            SpeedupTotal = $SpeedupOmpTotal
            SpeedupNeto = $SpeedupOmpNeto
            Integridad = $ResOmp.Integridad
        },
        @{
            Metodo = "CUDA"
            CifradoTotalMs = $ResCuda.CifradoTotalMs
            CifradoNetoMs = $ResCuda.CifradoNetoMs
            CifradoTputTotal = $ResCuda.CifradoTputTotal
            CifradoTputNeto = $ResCuda.CifradoTputNeto
            SpeedupTotal = $SpeedupCudaTotal
            SpeedupNeto = $SpeedupCudaNeto
            Integridad = $ResCuda.Integridad
        }
    )
}

$JSONData | ConvertTo-Json -Depth 5 | Out-File -FilePath $JSONPath -Encoding utf8
Write-Host "[+] Resultados guardados en: $JSONPath" -ForegroundColor Green
