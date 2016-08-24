# Jeremy Walker
# www.converged-tech.com
# Script for creating a nested vSphere environment

#
# Constants to use in environmnet deployment
#
$ovfPath = "C:\Scripts\ova\"
$envNumber = 0
$envPassword = 'ChangeMe'
$envClassB = '172.20.'
$envNTPServer = 'pool.ntp.org'
$envDNSServer = '172.20.10.5'

#
# Make connection to the lab vCenter
#
$vcserver = "ChangeMe.Domain.local"
$vcusername = "ChangeMe@vsphere.local"
$vcpassword = "ChangeMe"
Connect-VIServer -Server $vcserver -User $vcusername -Password $vcpassword

#
# Calculate derived environment information
#
$VMHost = Get-VMHost | Sort MemoryGB | Select -first 1
$envNetwork = 'Datacenter' + $envNumber.ToString()
$envDataStore = $VMHost | Get-datastore | Sort FreeSpaceGB -Descending | Select -first 1
$envNetworkPrefix = $envClassB + ($envNumber + 100).ToString() + '.'

#
# Deploy the VCSA from ovf template
#
# Load OVF/OVA configuration into a variable
$ovffile = $ovfPath + "vmware-vcsa-6u2.ova"
$ovfconfig = Get-OvfConfiguration $ovffile
$VCSAName = "VCSA" + $envNumber
$Network = Get-VirtualPortGroup -Name $envNetwork -VMHost $VMhost

# Fill out the OVF/OVA configuration parameters
$ovfconfig.NetworkMapping.Network_1.value = $envNetwork
$ovfconfig.DeploymentOption.value = "tiny"
$ovfconfig.IpAssignment.IpProtocol.value = "IPv4"
$ovfconfig.Common.guestinfo.cis.appliance.net.addr.family.value = "ipv4"
$ovfconfig.Common.guestinfo.cis.appliance.net.mode.value = "static"
$ovfconfig.Common.guestinfo.cis.appliance.net.addr_1.value = $envNetworkPrefix + "10"
$ovfconfig.Common.guestinfo.cis.appliance.net.pnid.value  = $envNetworkPrefix + "10"
$ovfconfig.Common.guestinfo.cis.appliance.net.prefix.value = "24"
$ovfconfig.Common.guestinfo.cis.appliance.net.gateway.value = $envNetworkPrefix + "1"
$ovfconfig.Common.guestinfo.cis.appliance.net.dns.servers.value = $envDNSServer
$ovfconfig.Common.guestinfo.cis.appliance.root.passwd.value = $envPassword
$ovfconfig.Common.guestinfo.cis.appliance.ssh.enabled.value = "True"
$ovfconfig.Common.guestinfo.cis.vmdir.domain_name.value = "vsphere.local"
$ovfconfig.Common.guestinfo.cis.vmdir.site_name.value = "Default-First-Site"
$ovfconfig.Common.guestinfo.cis.vmdir.password.value = $envPassword
$ovfconfig.Common.guestinfo.cis.appliance.ntp.servers.value = $envNTPServer

# Deploy the OVF/OVA with the config parameters
Write-Host "Deploying VCSA: $VCSAName ..."
$VCSAvm = Import-VApp -Source $ovffile -OvfConfiguration $ovfconfig -Name $VCSAName -VMHost $vmhost -Datastore $envDatastore -DiskStorageFormat thin | Out-Null
Write-Host "`tPowering on $VCSAName ..."
Start-VM $VCSAName -RunAsync | Out-Null
Write-Host

$ovffile = $ovfPath + "esxi_appliance_6u2.ova"
$ovfconfig = Get-OvfConfiguration $ovffile
$ovfconfig.NetworkMapping.VM_Network.value = $network_ref

20..25 | Foreach {
    $vmname = "vESXi$_"
    $ipaddress = "$envNetworkPrefix$_"
    
    $ovfconfig.common.guestinfo.hostname.value = $vmname
    $ovfconfig.common.guestinfo.ipaddress.value = $ipaddress
    $ovfconfig.common.guestinfo.netmask.value = "255.255.255.0"
    $ovfconfig.common.guestinfo.gateway.value = $envNetworkPrefix + "1"
    $ovfconfig.common.guestinfo.dns.value = $envDNSServer
    $ovfconfig.common.guestinfo.domain.value = "local"
    $ovfconfig.common.guestinfo.ntp.value = $envNTPServer
    $ovfconfig.common.guestinfo.password.value = $envPassword
    $ovfconfig.common.guestinfo.ssh.value = "True"

    # Deploy the OVF/OVA with the config parameters
    Write-Host "Deploying vEsxi host: $vmname ..."
    $vm = Import-VApp -Source $ovffile -OvfConfiguration $ovfconfig -Name $vmname -VMHost $vmhost -Datastore $envDatastore -DiskStorageFormat thin | Out-Null
    Write-Host "`tPowering on $vmname ..."
    Start-Vm $vmname -RunAsync | Out-Null
}
Write-Host

Disconnect-VIServer -Server $vcserver -Confirm:$false