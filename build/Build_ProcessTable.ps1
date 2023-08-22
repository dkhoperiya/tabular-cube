param
(
	[String] [Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$Server,

	[String] [Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$CubeDatabase,

	[String] [Parameter(Mandatory = $false)]
	[AllowEmptyString()]  
	$CubeTable,
	
	[String] [Parameter(Mandatory = $false)]
	[ValidateSet('Full', 'Automatic', 'ClearValues', 'Calculate')]
	$RefreshType = 'Full',
	
	[PSCredential] [Parameter(Mandatory = $false)]
	$Credential = $null
)
	
function Get-SsasProcessingMessages {
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

function ProcessTable {
    [CmdletBinding()]
    param
    (
        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $Server,

        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $CubeDatabase,
        
		[String] [Parameter(Mandatory = $false)]
		[AllowEmptyString()]  
		$CubeTable = "",
	
		[String] [Parameter(Mandatory = $false)]
        [ValidateSet('Full', 'Automatic', 'ClearValues', 'Calculate')]
        $RefreshType = 'Full',
		
        [PSCredential] [Parameter(Mandatory = $false)]
        $Credential = $null

    )

    try {

        

		if ("" -eq $CubeTable) {
			Write-Output "Расчет куба $CubeDatabase на SSAS Server $Server. Тип расчета: $RefreshType";
			
			$tmslStructure = [pscustomobject]@{
				refresh = [pscustomobject]@{
					type = $RefreshType
					objects = @( [pscustomobject]@{ database = $CubeDatabase } )
				}
			}
		} else {
			Write-Output "Расчет таблицы $CubeTable куба $CubeDatabase на SSAS Server $Server. Тип расчета: $RefreshType";
			$tmslStructure = [pscustomobject]@{
				refresh = [pscustomobject]@{
					type = $RefreshType
					objects = @( [pscustomobject]@{ 
						database = $CubeDatabase 
						table =  $CubeTable
					})
				}
			}
		}

        $tmsl = $tmslStructure | ConvertTo-Json -Depth 3;
        # Write-Output $tmsl;

        if ($null -eq $Credential) {
            $returnResult = Invoke-ASCmd -Server $Server -ConnectionTimeout 1 -Query $tmsl;
        } else {
            $returnResult = Invoke-ASCmd -Server $Server -Credential $Credential -ConnectionTimeout 1 -Query $tmsl;
        }
        Get-SsasProcessingMessages -ASCmdReturnString $returnResult;
    } 
    catch {
		$returnError = Get-SsasProcessingMessages -ASCmdReturnString $returnResult;
        throw "ProcessTable: Ошибка расчета $CubeDatabase на SSAS Server: $Server $err `n $returnError";
    }
}

if (!$Server){
	$Server = "pmo-powerbi-01.ural.mts.ru"
}
if (!$CubeDatabase){
	$CubeDatabase = "CICDModel"
}

ProcessTable $Server $CubeDatabase $CubeTable $RefreshType $Credential