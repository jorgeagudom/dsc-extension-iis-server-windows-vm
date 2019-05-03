# Variables Comunes
$ResourceGroupName = "RG-Mat-IIS-Service"
$Location = "eastus2"
$vmName = "VM-MAT-IIS"
$ImageName = "MicrosoftWindowsServer:WindowsServer:2016-Datacenter-Server-Core:latest"
$VirtualNetworkName = "MatIIS-VNET"
$SubnetName = "MatIIS-SubVNET"
$SecurityGroupName = "MatIIS-NSG"
$PublicIpAddressName = "MatIIS-PublicIP"
$Size = "Standard_B2s"

# Crear grupo de recursos
New-AzResourceGroup -Name $ResourceGroupName -Location $Location

# Crea el objeto de usuario
$cred = Get-Credential -Message "Introduce el usuario y la contrase�a para la m�quina virtual."

# LOOP creaci�n de m�quinas virtuales

while ($i -lt 2)
  {
    $i++
    # Crea la m�quina virtual

    Write-Host "Instalando VM ..." -ForegroundColor Black -BackgroundColor Yellow

    $vmNameNum = $vmName + $i
    $VirtualNetworkNameNum = $VirtualNetworkName + $i
    $SubnetNameNum = $SubnetName + $i
    $PublicIpAddressNameNum = $PublicIpAddressName + $i

    New-AzVM `
      -ResourceGroupName $ResourceGroupName `
      -Name $vmNameNum `
      -Location $location `
      -ImageName $ImageName `
      -VirtualNetworkName $VirtualNetworkNameNum `
      -SubnetName $SubnetNameNum `
      -SecurityGroupName $SecurityGroupName `
      -PublicIpAddressName $PublicIpAddressNameNum `
      -Credential $cred `
      -Size $Size `
      -OpenPorts 80

    Write-Host "VM creada con �xito!!" -ForegroundColor Black -BackgroundColor Yellow

    # Instalaci�n IIS

    Write-Host "Instalando IIS con DSC..." -ForegroundColor Black -BackgroundColor Yellow

    $PublicSettings = '{"ModulesURL":"https://github.com/lilwhite/Proyecto-MAT/raw/master/Ejercicio-2/WebEmpresa.ps1.zip", "configurationFunction": "WebEmpresa.ps1\\MatIIS", "Properties": {"MachineName": '+'"'+$vmNameNum+'"'+'} }'

    Set-AzVMExtension `
      -ExtensionName "DSC" `
      -ResourceGroupName $ResourceGroupName `
      -VMName $vmNameNum `
      -Publisher "Microsoft.Powershell" `
      -ExtensionType "DSC" `
      -TypeHandlerVersion 2.7 `
      -SettingString $PublicSettings `
      -Location $Location

    Write-Host "Servidor IIS instalado con �xito!!" -ForegroundColor Black -BackgroundColor Yellow
}