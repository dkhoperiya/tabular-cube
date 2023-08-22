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

function BackupModel {
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

        Write-Output "Бэкап SSAS Server $Server модель $CubeDatabase";


        # проблема с доступом
        # $FolderName = "C:\Program Files\Microsoft SQL Server\MSAS15.MSSQLSERVER\OLAP\Backup\$CubeDatabase"
        # if (-not(Test-Path $FolderName)) {
        #   New-Item -ItemType "directory" -Path $FolderName
        # }    

        $BackupName ="$CubeDatabase $commitid.abf" 

        #Формируем скрипт
        $tmslStructure = [pscustomobject]@{
            backup = [pscustomobject]@{
                    database = $CubeDatabase 
                    file =  "C:\Program Files\Microsoft SQL Server\MSAS15.MSSQLSERVER\OLAP\Backup\$BackupName" 
                    allowOverwrite = $true
                    applyCompression = $true
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
            throw "Ошибка при бэкапе. SSAS Server: $Server модель $CubeDatabase `n$returnError"
        }

        Write-Output "Бэкап '$BackupName' SSAS Server $Server модель $CubeDatabase создан успешно"
	}
	catch {
        throw "Ошибка при бэкапе. SSAS Server: $Server модель $CubeDatabase `n$returnError"
    }	
}

BackupModel -Server $Server -CubeDatabase $CubeDatabase -Credential $Credential -commitid $commitid