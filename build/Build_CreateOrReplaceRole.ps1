param (
		[Parameter(Mandatory = $false)]
        [AllowEmptyString()]  
        [string] 
			$Server,
		[Parameter(Mandatory = $false)]
        [AllowEmptyString()]  
        [string] 
			$CubeDatabase,
        [PSCredential] [Parameter(Mandatory = $false)]
			$Credential = $null			
)
function Get-SsasMessages {
    [CmdletBinding()]
    param
    (
        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $ASCmdReturnString
    )

    $returnXml = New-Object -TypeName System.Xml.XmlDocument;
    $returnXml.LoadXml($ASCmdReturnString);

    [System.Xml.XmlNamespaceManager] $nsmgr = $returnXml.NameTable;
    $nsmgr.AddNamespace('xmlAnalysis',     'urn:schemas-microsoft-com:xml-analysis');
    $nsmgr.AddNamespace('rootNS',         'urn:schemas-microsoft-com:xml-analysis:empty');
    $nsmgr.AddNamespace('exceptionNS',  'urn:schemas-microsoft-com:xml-analysis:exception');

    $rows = $returnXML.SelectNodes("//xmlAnalysis:return/rootNS:root/exceptionNS:Messages/exceptionNS:Error", $nsmgr) ;
    foreach ($row in $rows) {
        throw $row.Description;
    }
}

function CreateRole {
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $Server,

        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $CubeDatabase,

        [PSCredential] [Parameter(Mandatory = $false)]
        $Credential = $null
    )
	try {

        #Получаем все роли в каталоге ..\roles
        $Role_FileList = Get-ChildItem -Path ..\roles -Recurse -Include *.json

		#Цикл по ролям
		foreach ($f in $Role_FileList){

            $Role_Name = (get-content -path $f.FullName  | Out-String | ConvertFrom-Json).name

            Write-Output "Создается роль $Role_Name SSAS Server $Server модель $CubeDatabase";
            

            $parsed_json = Get-Content -Path $f.FullName  | Out-String | ConvertFrom-Json 

			#Формируем скрипт
			$tmslStructure = [pscustomobject]@{
				createOrReplace = [pscustomobject]@{
					object = [pscustomobject]@{ 
						database = $CubeDatabase 
						role = $Role_Name
					}
					role = $parsed_json
				}
			}
			
			$tmsl = $tmslStructure | ConvertTo-Json -Depth 6;	
			# Write-Output $tmsl;
			
			if ($null -eq $Credential) {
				$returnResult = Invoke-ASCmd -Server $Server -ConnectionTimeout 1 -Query $tmsl;
			} else {
				$returnResult = Invoke-ASCmd -Server $Server -Credential $Credential -ConnectionTimeout 1 -Query $tmsl;
			}
			# Write-Output $returnResult
			Get-SsasMessages -ASCmdReturnString $returnResult;
		}

	}
	catch {
        throw "Ошибка при создании роли $Role_Name. SSAS Server: $Server модель $CubeDatabase $err;"
    }
	# $results = $import.GetEnumerator() | Where-Object { $_.role -eq 'Reader' }
	
}

CreateRole -Server $Server -CubeDatabase $CubeDatabase -Credential $Credential