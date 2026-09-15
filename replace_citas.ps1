$files = Get-ChildItem -Path "c:\Flutter_Proyectos\app_pruebas\lib" -Recurse -Filter *.dart
foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    $newContent = $content -creplace '\bCitas\b', 'Reservas' `
                           -creplace '\bcitas\b', 'reservas' `
                           -creplace '\bCITAS\b', 'RESERVAS' `
                           -creplace '\bCita\b', 'Reserva' `
                           -creplace '\bcita\b', 'reserva' `
                           -creplace '\bCITA\b', 'RESERVA'
    if ($content -cne $newContent) {
        [IO.File]::WriteAllText($file.FullName, $newContent, [System.Text.Encoding]::UTF8)
        Write-Host "Updated $($file.FullName)"
    }
}
