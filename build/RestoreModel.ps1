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
			$Credential = $null,	
            
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]  
        [string] 
            $commitid            
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
    $err = @()
    foreach ($row in $rows) {
        $err += $row.Description;
    }
    return $err -join "`n"
}

function RestoreModel {
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
        $Credential = $null,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]  
        [string] 
            $commitid          
    )
	try {

        Write-Output "Восстановление из бэкапа SSAS Server $Server модель $CubeDatabase";
        
        $BackupName ="$CubeDatabase $commitid.abf" 

        #Формируем скрипт
        $tmslStructure = [pscustomobject]@{
            restore = [pscustomobject]@{
                    database = $CubeDatabase 
                    file =  "C:\Program Files\Microsoft SQL Server\MSAS15.MSSQLSERVER\OLAP\Backup\$BackupName" 
                    allowOverwrite = $true
                    readWriteMode = "readWrite"
                    security = "copyAll"                 
            }
        }
        
        $tmsl = $tmslStructure | ConvertTo-Json -Depth 2;	
        # Write-Output $tmsl;
        
        if ($null -eq $Credential) {
            $returnResult = Invoke-ASCmd -Server $Server -ConnectionTimeout 1 -Query $tmsl;
        } else {
            $returnResult = Invoke-ASCmd -Server $Server -Credential $Credential -ConnectionTimeout 1 -Query $tmsl;
        }
        # Write-Output $returnResult
        $returnError = Get-SsasMessages -ASCmdReturnString $returnResult;
        # Write-Output $returnError
        if ($returnError){
            throw "Ошибка при восстановление из бэкапа. SSAS Server: $Server модель $CubeDatabase `n$returnError"
        }
        Write-Output "Восстановление из бэкапа '$BackupName' SSAS Server $Server модель $CubeDatabase прошло успешно"
	}
	catch {
        throw "Ошибка при восстановление из бэкапа. SSAS Server: $Server модель $CubeDatabase `n$returnError"
    }	
}

RestoreModel -Server $Server -CubeDatabase $CubeDatabase -Credential $Credential -commitid $commitid