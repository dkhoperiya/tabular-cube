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
	$DS_Name,
	
	[String] [Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$DS_Type,
	
	[String] [Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$DS_Protocol,

	[String] [Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$DS_Server,
	
	[String] [Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$DS_Database,
	
	[String] [Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$DS_AuthenticationKind, # = "UsernamePassword"
	
	[String] [Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$DS_Kind,
	
	[String] [Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$DS_Path,
	
	[String] [Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$DS_Username,
	
	[String] [Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	$DS_Password,
	
	[String] [Parameter(Mandatory = $false)]
	[AllowEmptyString()] 
	$DS_OptionsTimeout,		
			
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

function Cube_DataSource_CreateOrReplace {
    [CmdletBinding()]
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
        $DS_Name,
		
		[String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $DS_Type,
		
		[String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $DS_Protocol,
	
		[String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $DS_Server,
		
		[String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $DS_Database,
		
		[String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $DS_AuthenticationKind,
		
		[String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $DS_Kind,
		
		[String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $DS_Path,
		
		[String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $DS_Username,
		
		[String] [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $DS_Password,
		
		[String] [Parameter(Mandatory = $false)]
		[AllowEmptyString()] 
        $DS_OptionsTimeout,		
        		
        [PSCredential] [Parameter(Mandatory = $false)]
        $Credential = $null

    )

    try {
		Write-Output "Создается источник $DS_Name. SSAS Server $Server модель $CubeDatabase";
		if ($null -eq $DS_OptionsTimeout) {
			$tmslStructure = [pscustomobject]@{
				createOrReplace = [pscustomobject]@{
					object = [pscustomobject]@{ 
						database = $CubeDatabase 
						dataSource = $DS_Name
					}
					dataSource = [pscustomobject]@{ 
						type = $DS_Type 
						name = $DS_Name
						connectionDetails = [pscustomobject]@{
							protocol = $DS_Protocol
							address = [pscustomobject]@{ 
								server = $DS_Server
								database = $DS_Database
							}
							authentication = $null
							query = $null
						}
						credential = [pscustomobject]@{
							AuthenticationKind = $DS_AuthenticationKind
							EncryptConnection = $false
							kind = $DS_Kind
							path = $DS_Path
							Username = $DS_Username
							Password = $DS_Password
						}
					}
				}
			}
		}
		else {
			$tmslStructure = [pscustomobject]@{
				createOrReplace = [pscustomobject]@{
					object = [pscustomobject]@{ 
						database = $CubeDatabase 
						dataSource = $DS_Name
					}
					dataSource = [pscustomobject]@{ 
						type = $DS_Type 
						name = $DS_Name
						connectionDetails = [pscustomobject]@{
							protocol = $DS_Protocol
							address = [pscustomobject]@{ 
								server = $DS_Server
								database = $DS_Database
							}
							authentication = $null
							query = $null
						}
						options = @{ commandTimeout = $DS_OptionsTimeout}
						credential = [pscustomobject]@{
							AuthenticationKind = $DS_AuthenticationKind
							EncryptConnection = $false
							kind = $DS_Kind
							path = $DS_Path
							Username = $DS_Username
							Password = $DS_Password
						}
					}
				}
			}
		}

        $tmsl = $tmslStructure | ConvertTo-Json -Depth 4;
        # Write-Output $tmsl;

        if ($null -eq $Credential) {
            $returnResult = Invoke-ASCmd -Server $Server -ConnectionTimeout 1 -Query $tmsl;
        } else {
            $returnResult = Invoke-ASCmd -Server $Server -Credential $Credential -ConnectionTimeout 1 -Query $tmsl;
        }
		# Write-Output $returnResult
        Get-SsasMessages -ASCmdReturnString $returnResult;
    } 
    catch {
		$err = Get-SsasMessages -ASCmdReturnString $returnResult;
        throw "Ошибка при создании источника $DS_Name. SSAS Server: $Server модель $CubeDatabase `n$err;"
    }
}

Cube_DataSource_CreateOrReplace                          `
        -Server $Server                                  `
        -CubeDatabase $CubeDatabase                              `
        -DS_Name $DS_Name                                `
        -DS_Type $DS_Type                                `
        -DS_Protocol $DS_Protocol                        `
        -DS_Server $DS_Server                            `
        -DS_Database $DS_Database                        `
        -DS_AuthenticationKind $DS_AuthenticationKind    `
        -DS_Kind $DS_Kind                                `
        -DS_Path $DS_Path                                `
        -DS_Username $DS_Username                        `
        -DS_Password $DS_Password                        `
        -DS_OptionsTimeout $DS_OptionsTimeout            `
		-Credential $Credential                          