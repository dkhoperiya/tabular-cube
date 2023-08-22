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

function Get-ModuleByName {
    [CmdletBinding()]
    param
    (
        [String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $Name
    )

    try {
        # ensure module is installed
        if (!(Get-Module -ListAvailable -Name $Name)) {
            # if module is not installed
            Write-Output "Installing PowerShell module $Name for current user"
            Install-PackageProvider -Name NuGet -Force -Scope CurrentUser;
            Install-Module -Name $Name -Force -AllowClobber -Scope CurrentUser -Repository PSGallery -SkipPublisherCheck;
        }
        if (-not (Get-Module -Name $Name)) {
            # if module is not loaded
            Import-Module -Name $Name -DisableNameChecking;
        }
    }
    catch {
        Write-Error "Error $_";
    }
}

function Ping-SsasDatabase {
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


    Get-ModuleByName -Name SqlServer;

    if ($null -eq $Credential) {
        $returnResult = Invoke-ASCmd -Server $Server -ConnectionTimeout 1 -Query "<Discover xmlns='urn:schemas-microsoft-com:xml-analysis'><RequestType>DBSCHEMA_CATALOGS</RequestType><Restrictions /><Properties /></Discover>" 2>&1;
    } else {;
        $returnResult = Invoke-ASCmd -Server $Server -Credential $Credential -ConnectionTimeout 1 -Query "<Discover xmlns='urn:schemas-microsoft-com:xml-analysis'><RequestType>DBSCHEMA_CATALOGS</RequestType><Restrictions /><Properties /></Discover>" 2>&1;
    }

	# Get-Variable -Name returnResult -ValueOnly
    if ([string]::IsNullOrEmpty($returnResult)) {
        return $false;
    } else {
        $returnXml = New-Object -TypeName System.Xml.XmlDocument;
        $returnXml.LoadXml($returnResult);
		
		
		# Get-Variable -Name returnXml -ValueOnly

        [System.Xml.XmlNamespaceManager] $nsmgr = $returnXml.NameTable;

        $nsmgr.AddNamespace('xmlAnalysis',     'urn:schemas-microsoft-com:xml-analysis');
        $nsmgr.AddNamespace('rootNS',         'urn:schemas-microsoft-com:xml-analysis:rowset');
		

        $rows = $returnXML.SelectNodes("//xmlAnalysis:DiscoverResponse/xmlAnalysis:return/rootNS:root/rootNS:row/rootNS:CATALOG_NAME", $nsmgr) ;
        foreach ($row in $rows) {
            $FoundDb = $row.InnerText;
			
			# Get-Variable -Name FoundDb -ValueOnly
			
            if ($FoundDb -eq  $CubeDatabase) {
                return $true;
            }
        }
        return $false;
    }  
}


# Write-Output ("Ping Server:{0} CubeDatabase:{1}:" -f $Server, $CubeDatabase)  

Ping-SsasDatabase -Server $Server -CubeDatabase $CubeDatabase -Credential $Credential_