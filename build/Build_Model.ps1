param (
		[Parameter(Mandatory = $false)]
        [AllowEmptyString()]  
        [string] 
			$Server,
		[Parameter(Mandatory = $false)]
        [AllowEmptyString()]  
        [string] 
			$CubeDatabase,
		[Parameter(Mandatory = $false)]
		#[ValidateNotNull()]
		[System.Management.Automation.PSCredential]
		[System.Management.Automation.Credential()]
			$Credential = $null #= [System.Management.Automation.PSCredential]::Empty
)

# -O / -OVERWRITE
# -R / -ROLES
# -M / -MEMBERS

# -P / -PARTITIONS 
# -C / -CONNECTIONS


# -G / -GITHUB        Output GitHub Actions workflow commands
# -W / -WARN        Outputs information about unprocessed objects as warnings

# -E / -ERR         Returns a non-zero exit code

# -O -C -P -R -M -W -E -G

if ($null -eq $Credential){
	$p =  Start-Process -filePath .\TabularEditor.exe -Wait -NoNewWindow -PassThru -RedirectStandardOutput ".\CreateModel.txt"`
       -ArgumentList "`"..\database.json`" -D `"$Server`" `"$CubeDatabase`" -O -R -M -E -P -G -W" 
}
else {
	$p = Start-Process -filePath .\TabularEditor.exe -Wait -NoNewWindow -PassThru -RedirectStandardOutput ".\CreateModel.txt"`
       -ArgumentList "`"..\database.json`" -D `"$Server`" `"$CubeDatabase`" -O -R -M -E -P -G -W" `
	   -Credential $Credential
}

$fullfile = Get-Content ".\CreateModel.txt" 
Write-Output $fullfile

if ($?){
	$p.ExitCode > (".\artifacts\Build_{0}_{1}.txt" -f $Server, $CubeDatabase) 
	Write-Output $p.ExitCode
	if ($p.ExitCode -eq 1){
		throw ("Ошибка при создании модели: {0}" -f $CubeDatabase)	
	}
}
else{
	throw ("Ошибка при создании модели: {0}" -f $CubeDatabase)
}
