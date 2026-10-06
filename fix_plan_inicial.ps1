$ErrorActionPreference = "Stop"
$ruta = "lib\screens\checkout_screen.dart"
if (-not (Test-Path $ruta)) {
    Write-Host "ERROR: no se encuentra $ruta" -ForegroundColor Red
    exit 1
}
Copy-Item $ruta "$ruta.bak" -Force
Write-Host "Backup creado en $ruta.bak" -ForegroundColor Green

$rutaAbs = (Resolve-Path $ruta).Path
$bytes = [System.IO.File]::ReadAllBytes($rutaAbs)
$contenido = [System.Text.Encoding]::UTF8.GetString($bytes)

# ---- CAMBIO 1: variable de estado ----
$b1_old = "  DateTime `_planFechaInicio = DateTime.now();`r`n  String? `_planCuotasError;"
$b1_new = "  DateTime `_planFechaInicio = DateTime.now();`r`n  String? `_planCuotasError;`r`n  // Si es true, el campo Inicial se interpreta en Bs y se`r`n  // convierte a USD usando la tasa paralelo antes de enviarlo al server.`r`n  bool `_planInicialEnBs = false;"
if (-not $contenido.Contains($b1_old)) { Write-Host "ERROR: bloque 1 no encontrado" -ForegroundColor Red; exit 1 }
$contenido = $contenido.Replace($b1_old, $b1_new)
Write-Host "Cambio 1 OK" -ForegroundColor Green

# ---- CAMBIO 2: reset ----
$b2_old = "    `_planObservacionesController.clear();`r`n    `_planFechaInicio = DateTime.now();`r`n    `_planCuotasError = null;"
$b2_new = "    `_planObservacionesController.clear();`r`n    `_planFechaInicio = DateTime.now();`r`n    `_planCuotasError = null;`r`n    `_planInicialEnBs = false;"
if (-not $contenido.Contains($b2_old)) { Write-Host "ERROR: bloque 2 no encontrado" -ForegroundColor Red; exit 1 }
$contenido = $contenido.Replace($b2_old, $b2_new)
Write-Host "Cambio 2 OK" -ForegroundColor Green

# ---- CAMBIO 5 PRIMERO (construir plan) para eliminar la linea montoInicial duplicada ----
$b5_old = "  Map<String, dynamic>? `_construirPlanCuotas(double totalVentaUsd) {`r`n    if (!`_planCuotasActivo) return null;`r`n`r`n    final montoInicial = `_parseMonto(`_planMontoInicialController.text);`r`n    final nCuotas = int.tryParse(`_planNumeroCuotasController.text.trim()) ?? 0;`r`n    final dias = int.tryParse(`_planDiasEntreCuotasController.text.trim()) ?? 0;"
$b5_new = "  Map<String, dynamic>? `_construirPlanCuotas(double totalVentaUsd) {`r`n    if (!`_planCuotasActivo) return null;`r`n`r`n    // Leer el monto crudo tal como lo escribio el usuario.`r`n    final montoCrudo = `_parseMonto(`_planMontoInicialController.text);`r`n`r`n    // Si el usuario eligio Bs, convertir a USD con la tasa paralelo.`r`n    final tasaParalelo = context.read<TasasProvider>().tasaParalelo;`r`n    final double montoInicial;`r`n    if (`_planInicialEnBs) {`r`n      if (tasaParalelo <= 0) {`r`n        `_planCuotasError = 'No hay tasa paralelo disponible para convertir Bs';`r`n        return null;`r`n      }`r`n      montoInicial = montoCrudo / tasaParalelo;`r`n    } else {`r`n      montoInicial = montoCrudo;`r`n    }`r`n`r`n    final nCuotas = int.tryParse(`_planNumeroCuotasController.text.trim()) ?? 0;`r`n    final dias = int.tryParse(`_planDiasEntreCuotasController.text.trim()) ?? 0;"
if (-not $contenido.Contains($b5_old)) { Write-Host "ERROR: bloque 5 no encontrado" -ForegroundColor Red; exit 1 }
$contenido = $contenido.Replace($b5_old, $b5_new)
Write-Host "Cambio 5 OK" -ForegroundColor Green

# ---- CAMBIO 3: preview del bloque (ancla sin acentos: termina en "final financiado =") ----
$b3_old = "    final montoInicial = `_parseMonto(`_planMontoInicialController.text);`r`n    final nCuotas = int.tryParse(`_planNumeroCuotasController.text.trim()) ?? 0;`r`n    final dias = int.tryParse(`_planDiasEntreCuotasController.text.trim()) ?? 0;`r`n`r`n    final financiado ="
$b3_new = "    final montoCrudoPreview = `_parseMonto(`_planMontoInicialController.text);`r`n    final tasaPreview = context.watch<TasasProvider>().tasaParalelo;`r`n    final montoInicial = (`_planInicialEnBs && tasaPreview > 0)`r`n        ? montoCrudoPreview / tasaPreview`r`n        : montoCrudoPreview;`r`n    final nCuotas = int.tryParse(`_planNumeroCuotasController.text.trim()) ?? 0;`r`n    final dias = int.tryParse(`_planDiasEntreCuotasController.text.trim()) ?? 0;`r`n`r`n    final financiado ="
if (-not $contenido.Contains($b3_old)) { Write-Host "ERROR: bloque 3 no encontrado" -ForegroundColor Red; exit 1 }
$contenido = $contenido.Replace($b3_old, $b3_new)
Write-Host "Cambio 3 OK" -ForegroundColor Green

# ---- CAMBIO 4: widget del campo ----
$b4_old = "                    decoration: const InputDecoration(`r`n                      isDense: true,`r`n                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 10),`r`n                      labelText: 'Inicial (USD)',`r`n                      border: OutlineInputBorder(),`r`n                      prefixText: '\$ ',`r`n                    ),"
$b4_new = "                    decoration: InputDecoration(`r`n                      isDense: true,`r`n                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),`r`n                      labelText: `_planInicialEnBs ? 'Inicial (Bs)' : 'Inicial (USD)',`r`n                      border: const OutlineInputBorder(),`r`n                      prefixText: `_planInicialEnBs ? 'Bs ' : '\$ ',`r`n                      suffixIcon: TextButton(`r`n                        onPressed: () {`r`n                          setState(() {`r`n                            `_planInicialEnBs = !`_planInicialEnBs;`r`n                            `_planCuotasError = null;`r`n                          });`r`n                        },`r`n                        style: TextButton.styleFrom(`r`n                          padding: const EdgeInsets.symmetric(horizontal: 6),`r`n                          minimumSize: const Size(0, 0),`r`n                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,`r`n                        ),`r`n                        child: Text(`r`n                          `_planInicialEnBs ? 'Bs' : 'USD',`r`n                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),`r`n                        ),`r`n                      ),`r`n                    ),"
if (-not $contenido.Contains($b4_old)) { Write-Host "ERROR: bloque 4 no encontrado" -ForegroundColor Red; exit 1 }
$contenido = $contenido.Replace($b4_old, $b4_new)
Write-Host "Cambio 4 OK" -ForegroundColor Green

# ---- GUARDAR SIN BOM ----
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$bytesSalida = $utf8NoBom.GetBytes($contenido)
[System.IO.File]::WriteAllBytes($rutaAbs, $bytesSalida)

Write-Host ""
Write-Host "LISTO. Los 5 cambios fueron aplicados." -ForegroundColor Green
Write-Host "Backup en: $ruta.bak" -ForegroundColor Green