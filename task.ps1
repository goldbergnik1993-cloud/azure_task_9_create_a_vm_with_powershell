$location = "northeurope"
$resourceGroupName = "mate-azure-task-9"
$networkSecurityGroupName = "defaultnsg"
$virtualNetworkName = "vnet"
$subnetName = "default"
$vnetAddressPrefix = "10.0.0.0/16"
$subnetAddressPrefix = "10.0.0.0/24"
$publicIpAddressName = "linuxboxpip"
$vmName = "matebox"
$vmSize = "Standard_D2s_v3"

# Путь к твоему ключу
$sshKeyPath = "$HOME/.ssh/id_ed25519.pub"
$sshKeyPublicKey = Get-Content $sshKeyPath

Write-Host "1. Creating Resource Group..."
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force

Write-Host "2. Creating Network Security Group..."
$nsgRuleSSH = New-AzNetworkSecurityRuleConfig -Name SSH -Protocol Tcp -Direction Inbound -Priority 1001 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22 -Access Allow
$nsgRuleHTTP = New-AzNetworkSecurityRuleConfig -Name HTTP -Protocol Tcp -Direction Inbound -Priority 1002 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 8080 -Access Allow
$nsg = New-AzNetworkSecurityGroup -Name $networkSecurityGroupName -ResourceGroupName $resourceGroupName -Location $location -SecurityRules $nsgRuleSSH, $nsgRuleHTTP

Write-Host "3. Creating VNet and Subnet..."
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name $subnetName -AddressPrefix $subnetAddressPrefix
$vnet = New-AzVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnetConfig

Write-Host "4. Creating Public IP..."
$publicIp = New-AzPublicIpAddress -Name $publicIpAddressName -ResourceGroupName $resourceGroupName -Location $location -AllocationMethod Static -Sku Standard

Write-Host "5. Creating Network Interface..."
$nic = New-AzNetworkInterface -Name "nic-$vmName" -ResourceGroupName $resourceGroupName -Location $location -SubnetId $vnet.Subnets.Id -PublicIpAddressId $publicIp.Id -NetworkSecurityGroupId $nsg.Id

Write-Host "6. Configuring VM..."
# Создаем объект Credential (имя пользователя 'azureuser' и временный пароль)
$securePassword = ConvertTo-SecureString "TempPassword123!" -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("azureuser", $securePassword)

$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize
# ВАЖНО: Используем -Credential вместо -AdminUsername
$vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Linux -ComputerName $vmName -Credential $cred
$vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName "Canonical" -Offer "ubuntu-24_04-lts" -Skus "server" -Version "latest"
$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
$vmConfig = Add-AzVMSshPublicKey -VM $vmConfig -KeyData $sshKeyPublicKey -Path "/home/azureuser/.ssh/authorized_keys"

Write-Host "7. Starting Deployment (please wait)..."
New-AzVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig

