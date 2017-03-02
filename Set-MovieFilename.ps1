param(
    [Parameter(Mandatory = $true)]
    [string]$File,

    [Parameter(Mandatory = $true)]
    [string]$Destination

)

Import-Module BitsTransfer

$item = Get-Item -LiteralPath $File

$explodedFile = $file.Substring(0,$file.Length-4).replace('.',' ').split('\')[-1].split(' ')

# Resolutions
$ignoreTerms  = @('720','720p','1080','1080p')

# Encodings
$ignoreTerms += @('x264')

# Types of torrents
$ignoreTerms += @('bluray','brrip','dvdrip','hc','hd','web-dl','ts','hdts')

# Ripping groups
$ignoreTerms += @('yify')

# Filetypes
$ignoreTerms += @('m4v','mp4','mkv','avi')

$explodedFile = $explodedFile | Where-Object {$_ -notin $ignoreTerms}

$counter = 2

$success = $false
while (!$success) {
    $possibleTitle = "$($explodedFile[0..($explodedFile.count - $counter)] -join " ")"
    $year = $explodedFile[-($counter-1)]

    Write-Host "Checking $possibleTitle ($year)..."
    $omdbURL = "omdbapi.com/?t=$possibleTitle&y=$year&r=JSON"
    $omdbResponse = Invoke-RestMethod -Method GET -Uri $omdbURL
    if ($omdbResponse.Response -eq "True") {
        Write-Host "Title matched: $($omdbResponse.Title) ($($omdbResponse.Year)).$($File.Split(".")[-1])" -ForegroundColor Green
        $success = $true
    }
    else {
        Write-Host "Failed to match $possibleTitle ($year), trying again." -ForegroundColor Yellow
        $possibleTitle = $possibleTitle[0..($possibleTitle.count - 1)]
        $counter++
    }

}

$fileExt = $file.Substring($file.Length-3)

$newFilename = "$($omdbResponse.Title) ($($omdbResponse.Year)).$fileExt"

Add-Type -AssemblyName PresentationCore,PresentationFramework
$ButtonType = [System.Windows.MessageBoxButton]::YesNo
$MessageboxTitle = “Rename File?”
$Messageboxbody = “Would you like to rename this file '$newFilename'?”
$MessageIcon = [System.Windows.MessageBoxImage]::Warning
$answer = [System.Windows.MessageBox]::Show($Messageboxbody,$MessageboxTitle,$ButtonType,$MessageIcon)

if ($answer -eq "yes") {
    Try {
        Rename-Item -literalpath $($item.FullName) -NewName $newFilename -ErrorAction Stop
        Write-Host "Renamed file, copying to Movies share..."
        #Move-Item "$($item.directory)\$newFilename" -Destination "\\supersynology\movies\" -ErrorAction Stop
        
        Start-BitsTransfer -Source "$($item.directory)\$newFilename" -Destination $Destination -Description "Copying $newFilename" -DisplayName "Copying..."

        Write-Host "Finished copying. Delete entire directory?"

        $MessageboxTitle = “Delete entire directory?”
        $Messageboxbody = “File moved to Movies folder. Delete this entire directory?`r`n$($item.Directory)”
        $MessageIcon = [System.Windows.MessageBoxImage]::Warning
        $answer2 = [System.Windows.MessageBox]::Show($Messageboxbody,$MessageboxTitle,$ButtonType,$MessageIcon)

        if ($answer2 -eq "yes") {
            Remove-Item $($item.Directory) -Force -Recurse -ErrorAction Stop
        }
        else {
            Write-Host "Alright, no. Deleting just the one item, then."
            Remove-Item "$($item.Directory.FullName)\$newFilename" -Force -ErrorAction Stop
        }

    }
    Catch {
        Write-Host "Well, something went wrong: $($_.Exception)"
    }
    
}