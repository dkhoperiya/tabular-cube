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

function GetEditFileMeasures {
    # [CmdletBinding()]
	try {

            # последние изменные файлы, за искючением удаленных "--diff-filter=d"
            git diff-tree --no-commit-id --name-only ${$CI_COMMIT_REF_NAME}..master -r --diff-filter=d > Git_GetEdit_Measures.txt

            # $json_file_list = New-Object System.Collections.ArrayList
            $list = New-Object System.Collections.Generic.List[object]

            $lines = (Get-Content ".\Git_GetEdit_Measures.txt" | Select-Object)

            # Write-Output "line  $($line[0])"
            foreach($line in $lines) {
                if($line -match "tables/01 Key Measures/measures*"){
                    $list.Add($line.replace("/", "\"))
                }
            }

        return $list
	}
	catch {
        throw "Ошибка при получении измененных мер"
    }
}

Write-Output "################## `nИзменение\создание метрик `n##################"

#Получаем последние изменения мер с GIT
$json_file_list = GetEditFileMeasures

Write-Output "Список измененных мер: $json_file_list"

$measure_name_list = New-Object System.Collections.Generic.List[object]

foreach($item in $json_file_list){
    
    $file_path = $item
    $full_path = "..\" + $file_path

    # Write-Output "file_path :  $file_path"
    # Write-Output "full_path :  $full_path"
    
    #Разбор файла json
    $measure_json = Get-Content -Path $full_path -Encoding UTF8 | Out-String | ConvertFrom-Json 
    # Write-Output $measure_json
    
    $measure_name_list.Add($measure_json.Name)
    

    $TableMeasures = "01 Key Measures"

    $MeasureName = $measure_json.Name

    $MeasureExpression = $null
    $MeasureDetailRowsExpression = $null
    $MeasureFormatString = $null
    $MeasureIsHidden = $false
    $MeasureDisplayFolder = $null
    $MeasureDescription = $null    

    $OFS = "`r`n"
    $script_cs = " 

        var table = Model.Tables[`"$TableMeasures`"];
        var measures = table.Measures;
        Measure measure = null;
        if (measures.Contains(`"$MeasureName`")){
            measure = measures[`"$MeasureName`"];
        }
        else {
            measure = table.AddMeasure(`"$MeasureName`");
        }
    "
    if ($measure_json.expression){
        $MeasureExpression = $measure_json.expression
        $script_cs += $OFS + "measure.Expression = @`"$MeasureExpression`";"
    }

    if ($measure_json.formatString){
        $MeasureFormatString = $measure_json.formatString
        $script_cs += $OFS + "measure.FormatString = `"$MeasureFormatString`";"
    }

    if ($measure_json.detailRowsDefinition.expression){
        $MeasureDetailRowsExpression = $measure_json.detailRowsDefinition.expression   
        $script_cs += $OFS + "measure.DetailRowsExpression = @`"$MeasureDetailRowsExpression`";"
    }
    if ($measure_json.displayFolder){
        $MeasureDisplayFolder = $measure_json.displayFolder
        $MeasureDisplayFolder = $MeasureDisplayFolder.replace("\", "\\")
        $script_cs += $OFS + "measure.DisplayFolder = `"$MeasureDisplayFolder`";"
    }

    if ($measure_json.isHidden -eq $true){
        $MeasureIsHidden = "true"
        $script_cs += $OFS + "measure.IsHidden = $MeasureIsHidden;"
    }
    if ($measure_json.description){
        $MeasureDescription = $measure_json.description
        $script_cs += $OFS + "measure.Description = `"$MeasureDescription`";"
    }

    #Write-Output $script_cs 

    $script_cs | Out-File -FilePath ".\CreateMeasure.cs"

    $p = &{Start-Process -filePath .\TabularEditor.exe -Wait -NoNewWindow -PassThru `
        -ArgumentList "`"$Server`" `"$CubeDatabase`" -S `".\CreateMeasure.cs`" -D `"$Server`" `"$CubeDatabase`" -O -E"}          

    if (!$?){
        throw ("Ошибка при создании мер: {0}" -f $CubeDatabase)
    }	   

}

# скидываем новые меры в файл для дальнейшей проверки на корректность
$measure_name_list | Out-File -FilePath ".\Edit_Measures_List"

# $p.ExitCode > (".\artifacts\create_measures {0}_{1}.txt" -f $Server, $CubeDatabase) 
# exit 0
# Проверка на этом этапе невозможна, т.к мера уже будет создана и при повторном запуске будет генерировать постоянную ошибку