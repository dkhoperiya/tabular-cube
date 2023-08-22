param (
		[Parameter(Mandatory = $false)]
        [AllowEmptyString()]  
        [string] $Server
)

function Ping-SsasServer {
    [OutputType([Boolean])]
    [CmdletBinding()]
    param
    (
            [String] [Parameter(Mandatory = $true)]
            [ValidateNotNullOrEmpty()]
            $Server
    )

    if ($Server -like "asazure*") {
        throw "Azure Analysis Services not supported. Only on-premise servers are supported by Ping-SsasServer";
    }
    try {
        [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices") | Out-Null;
        $ssasServer = New-Object Microsoft.AnalysisServices.Server;
        $ssasServer.connect($Server);
        if ($ssasServer.Connected -eq $false) {
            return $false;
        }

        $ssasServer.disconnect();

        return $true;
    } catch {
        return $false;
    }
}

# $userName = "evtkachev"
# $password = ConvertTo-SecureString -String "password" -AsPlainText -Force
# $Credential_ = New-Object -TypeName "System.Management.Automation.PSCredential" -ArgumentList $userName, $password

if (!$Server){
	$Server = "pmo-powerbi-01.ural.mts.ru"
}

Write-Output ("Ping Server:{0}" -f $Server)  

$GetResult = Ping-SsasServer -Server $Server

if ($GetResult -eq $false)
{
	throw ("Сервер {0} недоступен" -f $Server)
}
else{
	Write-Output $GetResult
}