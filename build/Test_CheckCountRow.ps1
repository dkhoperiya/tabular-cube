param
(
	[String] [Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$Server,

	[String] [Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$CubeDatabase
)

$fullfile = Get-Content ".\CheckCountRow.cs" 
Write-Output $fullfile

$p = &{Start-Process -filePath .\TabularEditor.exe -Wait -NoNewWindow -PassThru `
    -ArgumentList "`"$Server`" `"$CubeDatabase`" -S `".\CheckCountRow.cs`" -D `"$Server`" `"$CubeDatabase`" -O -E"}          

Write-Output "Результат запроса:"	
$CountRow = Get-Content ".\artifacts\CountRow.csv" 
Write-Output $CountRow

    
if (!$?){
    throw ("Ошибка при подсчёте кол-ва строк. Модель {0}" -f $CubeDatabase)
}	   

