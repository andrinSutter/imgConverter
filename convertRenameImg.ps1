function Get-AllImages {
    param (
        [string]$folderPath,
        [string[]]$fileExtensions
    )

    $allImages = Get-ChildItem -Path $folderPath -Recurse -File |
                 Where-Object { $fileExtensions -contains $_.Extension }

    return $allImages
}

function Get-ImageCreationDate {
    param (
        [string]$imagePath
    )

    $fileInfo = Get-Item -Path $imagePath
    return $fileInfo.CreationTime
}

function Get-DateTaken {
    param (
        [string]$imagePath
    )
    try {
        # Use the Windows Imaging Component to read the metadata
        $shellApp = New-Object -ComObject Shell.Application
        $folder = $shellApp.Namespace((Get-Item $imagePath).DirectoryName)
        $file = $folder.ParseName((Get-Item $imagePath).Name)

        $dateTaken = $folder.GetDetailsOf($file, 12)
        Write-Host "Raw DateTaken for ${imagePath}: $dateTaken"

        if (-not [string]::IsNullOrWhiteSpace($dateTaken)) {
            # Remove extra characters and clean the string
            $cleanDateTaken = $dateTaken -creplace '[^\u0000-\u007F]', '' -replace '\s{2,}', ' '

            $dateFormats = @('MM/dd/yyyy HH:mm:ss', 'dd.MM.yyyy HH:mm:ss', 'yyyy-MM-ddTHH:mm:ss', 'yyyy:MM:dd HH:mm:ss', 'dd.MM.yyyy HH:mm')
            foreach ($format in $dateFormats) {
                try {
                    return [datetime]::ParseExact($cleanDateTaken, $format, $null)
                }
                catch {
                    # Ignore parse errors and try the next format
                }
            }
            return $null
        } else {
            return $null
        }
    }
    catch {
        return $null
    }
}

function Rename-Image {
    param (
        [string]$imagePath,
        [string]$newName,
        [int]$index
    )

    $directory = [System.IO.Path]::GetDirectoryName($imagePath)
    $extension = [System.IO.Path]::GetExtension($imagePath)

    do {
        $newPath = [System.IO.Path]::Combine($directory, "$newName-$index$extension")
        $index++
    } while (Test-Path $newPath)

    Rename-Item -Path $imagePath -NewName $newPath
    return $newPath
}

function Convert-ImageExtensionsToJpeg {
    param (
        [string]$folderPath,
        [string[]]$fileExtensions
    )
    $allImages = Get-AllImages -folderPath $folderPath -fileExtensions $fileExtensions
    foreach ($image in $allImages) {
        Write-Host "Processing image:" $image.FullName
        if ($image.Extension -ne ".jpeg") {
            $newFileName = [System.IO.Path]::ChangeExtension($image.FullName, ".jpeg")
            try {
                Rename-Item -Path $image.FullName -NewName $newFileName -Force
                Write-Host "Changed extension of $($image.FullName) to .jpeg"
            } catch {
                Write-Host "Failed to change extension of $($image.FullName) to .jpeg. Error: $_"
            }
        } else {
            Write-Host "File $($image.FullName) already has .jpeg extension. Skipping."
        }
    }
}

# Example usage
$folderPath = "C:\Users\u61069\Repository\LA4 IoT\Powershell\Test_Img"
$fileExtensions = @(".jpg", ".jpeg", ".png", ".bmp", ".gif", ".tiff", ".jfif", ".heic")

$allImages = Get-AllImages -folderPath $folderPath -fileExtensions $fileExtensions

$index = 1
foreach ($image in $allImages) {
    Write-Host "Found image:" $image.FullName
    $dateTaken = Get-DateTaken -imagePath $image.FullName

    if ($dateTaken -ne $null) {
        $formattedDate = $dateTaken.ToString("yyyy-MM-dd_HHmmss")
    } else {
        $creationDate = Get-ImageCreationDate -imagePath $image.FullName
        $formattedDate = "crd-" + $creationDate.ToString("yyyy-MM-dd_HHmmss")
    }

    $newName = "$formattedDate"
    $newPath = Rename-Image -imagePath $image.FullName -newName $newName -index $index
    Write-Host "Renamed to:" $newPath
    $index++
}

Convert-ImageExtensionsToJpeg -folderPath $folderPath -fileExtensions $fileExtensions