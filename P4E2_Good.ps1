
# ----------------------------
# CREACIÓN DE LOAD BALANCER
# ----------------------------

$ResourceGroupName = "RG-MatWebServer2"
$Location = "eastus2"
$PublicIPname = "LoadBalancerIP2"
$VNETname = "LbVNet2"
$SubNETname = "LbSubVNet2"


# se crea un grupo de recursos denominado myResourceGroupLoadBalancer en la ubicación EastUS:

New-AzResourceGroup `
  -ResourceGroupName $ResourceGroupName `
  -Location $Location


# Crear una dirección IP pública:
# -------------------------------
#
# Crear IP pública para el equilibrador de carga:

$publicIP = New-AzPublicIpAddress `
  -ResourceGroupName $ResourceGroupName `
  -Location $Location `
  -AllocationMethod "Static" `
  -Name $PublicIPname



# Creación de un equilibrador de carga:
# --------------------------------------
#
# Creamos grupo de direcciones IP de front-end y lo asociamos a la direción IP anterior

$frontendIP = New-AzLoadBalancerFrontendIpConfig `
  -Name "myFrontEndPool" `
  -PublicIpAddress $publicIP

# Creamos un grupo de direcciones de back-end al cual se conectarán las VMs:

$backendPool = New-AzLoadBalancerBackendAddressPoolConfig `
  -Name "myBackEndPool"

#Creamos el equilibrador de carga mediante los grupos de direcciones IP de front-end y back-end creados en los pasos anteriores:

$lb = New-AzLoadBalancer `
  -ResourceGroupName $ResourceGroupName `
  -Name "myLoadBalancer2" `
  -Location $Location `
  -FrontendIpConfiguration $frontendIP `
  -BackendAddressPool $backendPool



# Creación de un sondeo de estado:
#--------------------------------
#
# Para permitir que el equilibrador de carga supervise el estado de la aplicación, 
# utilice un sondeo de estado. 
# El sondeo de estado agrega o quita de forma dinámica las máquinas virtuales de 
# la rotación del equilibrador de carga en base a su respuesta a las comprobaciones 
# de estado. De forma predeterminada, una máquina virtual se quita de la 
# distribución del equilibrador de carga después de dos errores consecutivos en 
# un intervalo de 15 segundos.
#
# Creamos un sondeo de estado TCP que supervisa cada máquina virtual en el puerto TCP 80:

Add-AzLoadBalancerProbeConfig `
  -Name "myHealthProbe2" `
  -LoadBalancer $lb `
  -Protocol tcp `
  -Port 80 `
  -IntervalInSeconds 15 `
  -ProbeCount 2

# Para aplicar el sondeo de estado, actualizamos el equilibrador de carga:
Set-AzLoadBalancer -LoadBalancer $lb



# Creación de una regla de Load Balancer:
# ------------------------------------------
#
# as reglas de equilibrador de carga se utilizan para definir cómo se distribuye el tráfico a las 
# máquinas virtuales. Se define la configuración de IP front-end para el tráfico entrante y el grupo IP de 
# back-end para recibir el tráfico, junto con el puerto de origen y destino requeridos. 
# Para asegurarse de que solo las máquinas virtuales correctas reciban tráfico, también hay que definir 
# el sondeo de estado que se va usar.
#
# Creamos una regla para el LB que equilibra el tráfico en el puerto TCP 80:

$probe = Get-AzLoadBalancerProbeConfig -LoadBalancer $lb -Name "myHealthProbe2"

Add-AzLoadBalancerRuleConfig `
  -Name "myLoadBalancerRule2" `
  -LoadBalancer $lb `
  -FrontendIpConfiguration $lb.FrontendIpConfigurations[0] `
  -BackendAddressPool $lb.BackendAddressPools[0] `
  -Protocol Tcp `
  -FrontendPort 80 `
  -BackendPort 80 `
  -Probe $probe

# actualizamos el equilibrador de carga:
Set-AzLoadBalancer -LoadBalancer $lb



# Creación de Recursos de Red:
# ------------------------------------------
#
# Creamos una VirtualNet con una SvbVNet:


$subnetConfig = New-AzVirtualNetworkSubnetConfig `
  -Name $SubNETname `
  -AddressPrefix 192.168.1.0/24

$vnet = New-AzVirtualNetwork `
  -ResourceGroupName $ResourceGroupName `
  -Location $Location `
  -Name $VNETname `
  -AddressPrefix 192.168.0.0/16 `
  -Subnet $subnetConfig

# Creamos las NIC virtuales para las próximas VMs:

for ($i=1; $i -le 2; $i++)
{
   New-AzNetworkInterface `
     -ResourceGroupName $ResourceGroupName `
     -Name myVM$i `
     -Location $Location `
     -Subnet $vnet.Subnets[0] `
     -LoadBalancerBackendAddressPool $lb.BackendAddressPools[0]
}

# Creación de Máquinas Virtuales (AvailabilitySet):
# --------------------------------------------------
#
# Para mejorar la alta disponibilidad de la aplicación, colocamos las máquinas virtuales 
# en un conjunto de disponibilidad.

# Creaoms el Availability Set:

$availabilitySetName = "ASweb"

$availabilitySet = New-AzAvailabilitySet `
  -ResourceGroupName $ResourceGroupName `
  -Name $availabilitySetName `
  -Location $Location `
  -Sku aligned `
  -PlatformFaultDomainCount 2 `
  -PlatformUpdateDomainCount 2

# Usuario Administrador y Contraseña para las VMs:

$cred = Get-Credential

# Creamos las VMs:

$ImageName = "MicrosoftWindowsServer:WindowsServer:2016-Datacenter-Server-Core:latest"
$Size = "Standard_B2s"
$SecurityGroupName = "ASsecurityGroup"

for ($i=1; $i -le 2; $i++)
{
    # Instalamos el servidor web de IIS y después actualiza la página 
    # Default.htm para mostrar el nombre de host de la máquina virtual:
    $PublicSettings = '{"ModulesURL":"https://github.com/jorgeagudom/dsc-extension-iis-server-windows-vm/raw/master/MatIIS.ps1.zip", "configurationFunction": "MatIIS.ps1\\MatIIS", "Properties": {"vmName": '+'"'+$vmNameNum+'"'+'} }'
    $vmName = "myVM"
    Write-Host "Instalando VM ..." -ForegroundColor Black -BackgroundColor Yellow
    $vmNameNum = $vmName + $i
    New-AzVm `
        -ResourceGroupName $ResourceGroupName `
        -Name $vmNameNum `
        -Location $Location `
        -ImageName $ImageName `
        -VirtualNetworkName $VNETname `
        -SubnetName $SubNETname `
        -SecurityGroupName $SecurityGroupName `
        -OpenPorts 80,3389 `
        -Size $Size `
        -AvailabilitySetName $availabilitySetName `
        -Credential $cred

   Write-Host "VM creada con éxito!!" -ForegroundColor Black -BackgroundColor Yellow

   Write-Host "Instalando IIS con DSC..." -ForegroundColor Black -BackgroundColor Yellow
   
   Set-AzVMExtension `
     -ExtensionName "DSC" `
     -ResourceGroupName $ResourceGroupName `
     -VMName $vmNameNum `
     -Publisher "Microsoft.Powershell" `
     -ExtensionType "DSC" `
     -TypeHandlerVersion 2.7 `
     -SettingString $PublicSettings `
     -Location $Location 

   Write-Host "Servidor IIS instalado con éxito!!" -ForegroundColor Black -BackgroundColor Yellow
}