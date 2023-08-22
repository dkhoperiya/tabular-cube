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
	$Vault_Address,
	
	[String] [Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$VAULT_MOUNT_POINT,
	
	[String] [Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$VAULT_ROLE_ID,	

	[String] [Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$VAULT_SECRET_ID	
)

function CheckDataSource {
    [CmdletBinding()]
    param
    (
		[String] [Parameter(Mandatory = $false)]
        $Name,		
		
		[String] [Parameter(Mandatory = $false)]
        $Server,
		
		[String] [Parameter(Mandatory = $false)]
        $Database,
		
        [String] [Parameter(Mandatory = $false)]
        $Password,
		
		[String] [Parameter(Mandatory = $false)]
        $Username,

		[String] [Parameter(Mandatory = $false)]
        $AuthenticationKind,

		[String] [Parameter(Mandatory = $false)]
        $Kind,		
		
		[String] [Parameter(Mandatory = $false)]
        $Protocol,			
		
		[String] [Parameter(Mandatory = $false)]
        $Type
    )
	[bool] $err = $false

	Write-Host "Проверка ключей"

	if ($Name -eq "not present in secret"){
		$err = $true
		Write-Warning "Отсутствует ключ Name"
	}	
	if ($Server -eq "not present in secret"){
		$err = $true
		Write-Warning "Отсутствует ключ Server"
	}	
	if ($Database -eq "not present in secret"){
		$err = $true
		Write-Warning "Отсутствует ключ Database"
	}	
	if ($Password -eq "not present in secret"){
		$err = $true
		Write-Warning "Отсутствует ключ Password"
	}
	if ($Username -eq "not present in secret"){
		$err = $true
		Write-Warning "Отсутствует ключ Username"
	}
	if ($AuthenticationKind -eq "not present in secret"){
		$err = $true
		Write-Warning "Отсутствует ключ AuthenticationKind"
	}
	if ($Kind -eq "not present in secret"){
		$err = $true
		Write-Warning "Отсутствует ключ Kind"
	}	
	if ($Protocol -eq "not present in secret"){
		$err = $true
		Write-Warning "Отсутствует ключ Protocol"
	}	
	if ($Type -eq "not present in secret"){
		$err = $true
		Write-Warning "Отсутствует ключ Type"
	}		
	if (!$err){
		# exit $p.ExitCode
		Write-Host "Ключи корректны"
	}
	else{
		throw ("Ошибка при проверке ключей DataSource")
	}
}

function GetDataSource_Vault {
[CmdletBinding()]
    param
    (
		[String] [Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		$Vault_Address,
		
		[String] [Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		$VAULT_MOUNT_POINT,
		
		[String] [Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		$VAULT_ROLE_ID,	
	
		[String] [Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		$VAULT_SECRET_ID,	
	
		[String] [Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		$DataSource_Name

	)
	Write-Host "Получаем ключи DataSource: $DataSource_Name"

	try {
		#########
		# Подключение к Vault
		#########
		$ENV:VAULT_ADDR = $Vault_Address
		$VAULT_TOKEN = vault write -field=token auth/approle/login role_id="$VAULT_ROLE_ID" secret_id="$VAULT_SECRET_ID"

		vault login -method=token $VAULT_TOKEN 

		$Exists_DataSource = vault kv get $VAULT_MOUNT_POINT/DataSources/$DataSource_Name

		if (!$Exists_DataSource){
			throw ("Ошибка при получении данных в Vault. DataSource $DataSource_Name не найден")
		}

		$value = "" | Select-Object -Property Name,Server,Database,Username,Password,AuthenticationKind,Kind,Protocol,Type,Path,OptionsTimeout

		$value.Username = vault kv get -field=Username $VAULT_MOUNT_POINT/DataSources/$DataSource_Name
		$value.Password = vault kv get -field=Password $VAULT_MOUNT_POINT/DataSources/$DataSource_Name


		$value.AuthenticationKind = vault kv get -field=AuthenticationKind $VAULT_MOUNT_POINT/DataSources/$DataSource_Name
		$value.Database = vault kv get -field=Database $VAULT_MOUNT_POINT/DataSources/$DataSource_Name
		$value.Kind = vault kv get -field=Kind $VAULT_MOUNT_POINT/DataSources/$DataSource_Name
		$value.Name = vault kv get -field=Name $VAULT_MOUNT_POINT/DataSources/$DataSource_Name
		$value.Protocol = vault kv get -field=Protocol $VAULT_MOUNT_POINT/DataSources/$DataSource_Name
		$value.Server = vault kv get -field=Server $VAULT_MOUNT_POINT/DataSources/$DataSource_Name
		$value.Type = vault kv get -field=Type $VAULT_MOUNT_POINT/DataSources/$DataSource_Name
		$value.Path = $value.Server + ";" + $value.Database

		#Необязательные
		#$Path = vault kv get -field=Path $VAULT_MOUNT_POINT/DataSources/$DataSource_Name 
		$value.OptionsTimeout = vault kv get -field=OptionsTimeout $VAULT_MOUNT_POINT/DataSources/$DataSource_Name 
		if ($value.OptionsTimeout -eq "not present in secret"){
			$value.OptionsTimeout = $null
		}

		#Проверка ключей DataSource
		CheckDataSource `
				-Name $value.Name `
				-Server $value.Server `
				-Database $value.Database `
				-Username $value.Username `
				-Password $value.Password `
				-AuthenticationKind $value.AuthenticationKind `
				-Kind $value.Kind `
				-Protocol $value.Protocol `
				-Type $value.Type 
		return $value
	} 
	catch {
		$message = $_
		throw "Ошибка при получении данных в Vault. DataSource $DataSource_Name `n$message"
	}
	
}

########
# Создаем DataSource
########

$DataSource_FileList = Get-ChildItem -Path ..\dataSources -Recurse -Include *.json
# Write-Output $fileNames

foreach ($f in $DataSource_FileList){
	# Write-Output $f.FullName 

	$DataSource_Name = (get-content -path $f.FullName  | Out-String | ConvertFrom-Json).name

	# Write-Output $DataSource_Name

	$DWH_DS = GetDataSource_Vault `
			-Vault_Address $Vault_Address			`
			-VAULT_MOUNT_POINT $VAULT_MOUNT_POINT	`
			-VAULT_ROLE_ID $VAULT_ROLE_ID			`
			-VAULT_SECRET_ID $VAULT_SECRET_ID		`
			-DataSource_Name $DataSource_Name				

	# Write-Output $DWH_DS

	.\CreateOrReplaceDataSource.ps1 		`
			-Server	$Server		`
			-CubeDatabase $CubeDatabase 		`
			-DS_Name $DWH_DS.Name 			`
			-DS_Type $DWH_DS.Type 			`
			-DS_Protocol $DWH_DS.Protocol 	`
			-DS_Server $DWH_DS.Server 		`
			-DS_Database $DWH_DS.Database 	`
			-DS_AuthenticationKind $DWH_DS.AuthenticationKind `
			-DS_Kind $DWH_DS.Kind 			`
			-DS_Path $DWH_DS.Path 			`
			-DS_Username $DWH_DS.Username 	`
			-DS_Password $DWH_DS.Password 	`
			-DS_OptionsTimeout $DWH_DS.OptionsTimeout
			#-Credential
}



