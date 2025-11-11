$packageUrl = "https://www.nuget.org/api/v2/package/Microsoft.Web.WebView2/1.0.2792.45"
$outputZip = "webview2.zip"
$outputDir = "packages"

Write-Host "Downloading WebView2 SDK..."
Invoke-WebRequest -Uri $packageUrl -OutFile $outputZip

Write-Host "Extracting..."
Expand-Archive -Path $outputZip -DestinationPath "$outputDir/Microsoft.Web.WebView2.1.0.2792.45" -Force

Write-Host "Cleaning up..."
Remove-Item $outputZip

Write-Host "Done! WebView2 SDK installed to $outputDir"
