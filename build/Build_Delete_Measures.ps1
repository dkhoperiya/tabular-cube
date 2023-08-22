param
(
	[String] [Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$Server,

	[String] [Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$CubeDatabase,

    [String] [Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$CI_COMMIT_REF_NAME	
)

function GetDeleteMeasures {
    # [CmdletBinding()]
	try {

            # последние изменные файлы, удаленные меры "--diff-filter=d"
            git diff-tree --no-commit-id --name-only ${$CI_COMMIT_REF_NAME}..master -r --diff-filter=D > Git_GetDelete_Measures.txt

            # $json_file_list = New-Object System.Collections.ArrayList
            $list = New-Object System.Collections.Generic.List[object]

            $lines = (Get-Content ".\Git_GetDelete_Measures.txt" | Select-Object)

            # Write-Output "line  $($line[0])"
            foreach($line in $lines) {
                if($line -match "tables/01 Key Measures/measures*"){
                    $list.Add($line.replace("/", "\"))
                }
            }

        return $list
	}
	catch {
        throw "Ошибка при получении удаленных"
    }
}

Write-Output "################## `nУдаление метрик `n##################"

#Получаем последние изменения мер с GIT
$json_file_list = GetDeleteMeasures


$measure_name_list = @()

foreach($item in $json_file_list){
    
    $measure_name = $item.split("\")[3]
    $measure_name = $measure_name.replace(".json", "")

    Write-Output "measure_name :  $measure_name"

    $measure_name_list += "`"" + $measure_name + "`"" 
}

$measure_name_list = $measure_name_list -join ","

if ($measure_name_list){
    Write-Output "Список удаленных метрик: $measure_name_list"

    $OFS = "`r`n"
    $script_cs = " 
        var count = 0;
        string[] m_list = {$measure_name_list};
        foreach(var m in Model.AllMeasures)
        {
            if (m_list.Contains(m.Name)){ 
                m.Delete();
                Info(`"Удалена метрика:`" + m.Name);
                count +=1;
            }
        }
        if (count > 0){
            Info(`"Удалено метрик `" + count); 
        }
    "

    #Write-Output $script_cs 

    $script_cs | Out-File -FilePath ".\DeleteMeasure.cs"

    $p = &{Start-Process -filePath .\TabularEditor.exe -Wait -NoNewWindow -PassThru `
        -ArgumentList "`"$Server`" `"$CubeDatabase`" -S `".\DeleteMeasure.cs`" -D `"$Server`" `"$CubeDatabase`" -O -E"}         
}

if (!$?){
    throw ("Ошибка при удалении метрики: {0}" -f $CubeDatabase)
}	
