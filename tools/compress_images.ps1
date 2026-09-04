Add-Type -AssemblyName System.Drawing

$images = Get-ChildItem -Path "assets/images" -Recurse -Include *.png, *.jpg, *.jpeg

Write-Host "Found $($images.Count) image files to compress..." -ForegroundColor Cyan

$count = 0
$savedBytes = 0

foreach ($file in $images) {
    try {
        $originalSize = $file.Length
        $srcBmp = [System.Drawing.Bitmap]::FromFile($file.FullName)
        
        $maxDimension = 400
        $w = $srcBmp.Width
        $h = $srcBmp.Height
        
        if ($w -gt $maxDimension -or $h -gt $maxDimension) {
            if ($w -gt $h) {
                $newW = $maxDimension
                $newH = [int]($h * ($maxDimension / $w))
            } else {
                $newH = $maxDimension
                $newW = [int]($w * ($maxDimension / $h))
            }
        } else {
            $newW = $w
            $newH = $h
        }

        $destBmp = New-Object System.Drawing.Bitmap($newW, $newH)
        $g = [System.Drawing.Graphics]::FromImage($destBmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
        $g.DrawImage($srcBmp, 0, 0, $newW, $newH)
        
        $g.Dispose()
        $srcBmp.Dispose()

        $tempPath = $file.FullName + ".tmp"
        $destBmp.Save($tempPath, [System.Drawing.Imaging.ImageFormat]::Png)
        $destBmp.Dispose()

        Remove-Item $file.FullName -Force
        Rename-Item $tempPath $file.FullName -Force

        $newSize = (Get-Item $file.FullName).Length
        $savedBytes += ($originalSize - $newSize)
        $count++
        
        $origKB = [math]::Round($originalSize / 1KB, 1)
        $newKB = [math]::Round($newSize / 1KB, 1)
        Write-Host "[$count/$($images.Count)] $($file.Name): ${origKB}KB -> ${newKB}KB" -ForegroundColor Green
    } catch {
        Write-Host "Error compressing $($file.Name): $_" -ForegroundColor Red
    }
}

$savedMB = [math]::Round($savedBytes / 1MB, 2)
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host " COMPRESSION COMPLETE! Saved ${savedMB} MB." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
