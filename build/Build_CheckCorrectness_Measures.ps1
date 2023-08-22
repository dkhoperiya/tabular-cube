param
(
	[String] [Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$Server,

	[String] [Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$CubeDatabase
)

Write-Output "################## `nПроверка корректности метрик `n##################"

$lines = (Get-Content ".\Edit_Measures_List" | Select-Object)
$measure_name_list = @()

foreach($line in $lines) {
    # Write-Output "line $line"
    $measure_name_list += "`"" + $line + "`""
}

$measure_name_list = $measure_name_list -join ","

# Write-Output "measure_name_list $measure_name_list"

$errMeasure = @()
$errMessage = "" # @()
$err = $false
if ($measure_name_list){
    Write-Output "Список метрик на проверку: $measure_name_list"
    $OFS = "`r`n"
    #m.Delete();
    $script_cs = " 
        var count = 0;
        string[] m_list = {$measure_name_list};
        foreach(var m in Model.AllMeasures)
        {
            if (m.ErrorMessage != `"`" && m_list.Contains(m.Name)){ 
                m.Delete();
                Info(`"Некорректная метрика:`" + m.Name + `":`" + m.ErrorMessage);
                count +=1;
            }
        }
        if (count > 0){
            Error(`"Удалено метрик с ошибками `" + count); 
        }
    "
    
    #Write-Output $script_cs 
    
    $script_cs | Out-File -FilePath ".\DeleteErrorMeasure.cs"
    # measure correctness check
    #-RedirectStandardInput "./TestSort.txt"
    $p = &{Start-Process -filePath .\TabularEditor.exe -Wait -NoNewWindow -PassThru -RedirectStandardOutput ".\CheckCorrectness_FullLog.txt"`
           -ArgumentList "`"$Server`" `"$CubeDatabase`" -S `".\DeleteErrorMeasure.cs`" -D `"$Server`" `"$CubeDatabase`" -O -E"}
    
    Write-Output "####################" 	   
    
    foreach($line in Get-Content ".\CheckCorrectness_FullLog.txt") {
        if($line -match "Script error*"){
            # Write-Output $line.Split(":")[1]
            $errMessage = $line.Split(":")[1]
            $err = $true
        }
        if($line -match "Error CS*"){
            $errMessage = $line
            $err = $true
        }    
        if($line -match "Некорректная метрика:*"){
            $errMeasure += $line.Split(":")[1]
            # $errMessage += $line.Split(":")[2]
        }
    }
    
    
    $fullfile = Get-Content ".\CheckCorrectness_FullLog.txt" 
}
else {
    Write-Output "Новые метрики на проверку отсутствуют"
}
  

if ($err){
    $errMeasure = $errMeasure -join ","
    Write-Output "$errMessage. Удаленные метрики: $errMeasure"
    Write-Output $fullfile

	throw ("$errMessage. Удаленные метрики: $errMeasure")
}	   
# $p.ExitCode > (".\artifacts\delete_measures {0}_{1}.txt" -f $Server, $CubeDatabase) 
Write-Output $fullfile
exit 0