$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$modelDir = Join-Path $root "assets\models"
New-Item -ItemType Directory -Force -Path $modelDir | Out-Null

$url = "https://huggingface.co/opencv/face_recognition_sface/resolve/main/face_recognition_sface_2021dec.onnx"
$out = Join-Path $modelDir "face_recognition_sface_2021dec.onnx"

Write-Host "Downloading SFace model (~37 MB)..."
Invoke-WebRequest -Uri $url -OutFile $out
Write-Host "Saved to: $out"
