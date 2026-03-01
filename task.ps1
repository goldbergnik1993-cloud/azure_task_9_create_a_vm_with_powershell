$location = "northeurope"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$sshKeyName = "linuxboxsshkey"
$vmName = "matebox"
$vmImage = "Ubuntu2204"
$vmSize = "Standard_D2s_v3"

$sshKeyPath = "$HOME/.ssh/id_ed25519.pub"
$sshKeyPublicKey = Get-Content $sshKeyPath

New-AzResourceGroup -Name $resourceGroupName -Location $location -Force

# 1. Создание ресурса SSH ключа в Azure (требование задачи)
$sshKey = New-AzSshKey -ResourceGroupName $resourceGroupName -Name $sshKeyName -Location $location -PublicKey $sshKeyPublicKey

$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow
$nsg = New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
$vnet = New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnetConfig

# 2. Создание IP с обязательным DNS Label
$dnsLabel = "matebox-nikita-$(Get-Random -Minimum 1000 -Maximum 9999)"
$publicIp = New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Static -Sku Standard -DomainNameLabel $dnsLabel

$nic = New-AzNetworkInterface -Name "nic-$vmName" -ResourceGroupName $resourceGroupName -Location $location -SubnetId $vnet.Subnets.Id -PublicIpAddressId $publicIp.Id -NetworkSecurityGroupId $nsg.Id

$securePassword = ConvertTo-SecureString "TempPass123!" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("azureuser", $securePassword)

# 3. Конфигурация ВМ с привязкой к ресурсу SSH ключа
$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize
$vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Linux -ComputerName $vmName -Credential $cred
$vmConfig = Set-AzVMSourceImage -VM $vmConfig -ImageName $vmImage
$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id

# Привязываем созданный ресурс SSH ключа по его ID
$vmConfig = Add-AzVMSshPublicKey -VM $vmConfig -KeyData $sshKeyPublicKey -Path "/home/azureuser/.ssh/authorized_keys"

New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig

