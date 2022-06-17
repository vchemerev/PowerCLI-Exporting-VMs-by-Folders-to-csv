Add-Type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
    ServicePoint srvPoint, X509Certificate certificate,
    WebRequest request, int certificateProblem) {
    return true;
    }
}

"@
$AllProtocols=[System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'
[System.Net.ServicePointManager]::SecurityProtocol=$AllProtocols
[System.Net.ServicePointManager]::CertificatePolicy=New-Object TrustAllCertsPolicy

function Get-VMFolderPath {
   
    param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [string]$folderid,
        [switch]$moref
    )

    $folderparent = get-view $folderid
    if ($folderparent.name -ne 'vm') {
        if ($moref) { $path = $folderparent.moref.toString() + '\' + $path }
        else {
            $path = $folderparent.name + '\' + $path
        }
        if ($folderparent.parent) {
            if ($moref) { get-vmfolderpath $folderparent.parent.tostring() -moref }
            else {
                get-vmfolderpath($folderparent.parent.tostring())
            }
        }
    }
    else {
        if ($moref) {
            return (get-view $folderparent.parent).moref.tostring() + '\' + $folderparent.moref.tostring() + '\' + $path
        }
        else {
            return (get-view $folderparent.parent).name.toString() + '\' + $folderparent.name.toString() + '\' + $path
        }
    }
}





# Specifying credentials
$vcenter = "vcenter-name"
$username = "user"
$password = 'password'


$foldername = "FolderName" # Folder name in vcenter to get VMs
$reportdir = 'C:\Foldername\filename.csv' # Place for a file exporting


# Connecting to a vcenter
connect-viserver -server $vcenter -user $username -password $password
$vms=0
$vms=Get-Folder $foldername| Get-VM    
$vms_sum= $vms.Count


$table=0
$s=0

# Exporting VMs by a specific  folder from vcenter
   ForEach   ($vm in $VMs) {
   $s=$s+1

   
   $row = "" | Select Name,DNS_Name,State,PowerState,Provisioned_Space,Used_Space,Guest_OS,Memory_Size,CPUs,@{N="Up Time";E={$Timespan = New-Timespan -Seconds (Get-Stat -Entity $VM.Name -Stat sys.uptime.latest -Realtime -MaxSamples 1).Value
    "" + $Timespan.Days + " Days, "+ $Timespan.Hours + " Hours, " +$Timespan.Minutes + " Minutes"}},IPAddress,@{Name='FullPath';Expression={Get-VM $vm.Name | Get-VMFolderPath}}
   echo "$s из $vms_sum"
   
   $row.Name = $vm.Name

   $row.DNS_Name = $vm.Guest.ExtensionData.HostName

   $row.PowerState = $vm.PowerState

   $row.State=$vm.ExtensionData.OverallStatus
   if ([math]::round($vm.ProvisionedSpaceGB) -ge 1024) {$psbg= [math]::round((($vm.ProvisionedSpaceGB)/1024),2);[string]$psbg=[string]$psbg+" TB"} else {$psbg= [math]::round($vm.ProvisionedSpaceGB,2);[string]$psbg=[string]$psbg+" GB" }  
   $row.Provisioned_Space=$psbg
   if ([math]::round($vm.UsedSpaceGB) -ge 1024) {$ussp= [math]::round((($vm.UsedSpaceGB)/1024),2);[string]$ussp=[string]$ussp+" TB"} else {$ussp= [math]::round($vm.UsedSpaceGB,2);[string]$ussp=[string]$ussp+" GB" }  
   $row.Used_Space=$ussp
   $row.Guest_OS = $vm.Guest.OSFullName
   if ([math]::round($vm.MemoryGB) -ge 1024) {$memsize= [math]::round((($vm.MemoryGB)/1024),2);[string]$memsize=[string]$memsize+" TB"} else {$memsize= [math]::round($vm.MemoryGB,2);[string]$memsize=[string]$memsize+" GB" }  
   $row.Memory_Size=$memsize
   $row.CPUs=$vm.NumCpu
   $row.IPAddress = $vm.Guest.IpAddress -join '|'

   
   $row|Export-Csv -Path $reportdir -NoTypeInformation -UseCulture -Append
   }

Set-Content -Path $reportdir -Value (get-content -Path $reportdir | Select-String -Pattern "$foldername|FullPath")
echo "Scripts is finished"
