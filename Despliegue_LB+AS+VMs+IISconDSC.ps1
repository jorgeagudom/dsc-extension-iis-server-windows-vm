# ----------------------------
# CREACIÓN DE LOAD BALANCER
# ----------------------------

# Variables:

$ResourceGroupName = "RG-MatWebServer"
$Location = "eastus2"

$PublicLB_IPname = "WebEmpresaIP"
$PublicIpAddressName = "WebServerPublicIP"

$frontendName = "LbFrontEndPool"
$backendName = "LbBackEndPool"
$LoadBalancerName = "WebLoadBalancer"
$HealthProbeName = "LbHealthProbe80"
#$LbRuleName = "LoadBalancerRule" podría ponerlo y probar, pero de momento no

$VNETname = "LbVNet2"
$SubNETname = "LbSubVNet2"

$availabilitySetName = "ASweb"

#$NICname = "NICvm" podría ponerlo y probar, pero de momento no
$vmName = "VMweb"

$ImageName = "MicrosoftWindowsServer:WindowsServer:2016-Datacenter-Server-Core:latest"
$Size = "Standard_B2s"
$SecurityGroupName = "ASsecurityGroup"


# Usuario Administrador y Contraseña para las VMs:

$cred = Get-Credential

# se crea un grupo de recursos denominado myResourceGroupLoadBalancer en la ubicación EastUS:

Write-Host "Creando Grupo de Recursos" -ForegroundColor Black -BackgroundColor Yellow

New-AzResourceGroup `
  -ResourceGroupName $ResourceGroupName `
  -Location $Location


# Crear una dirección IP pública para el LB:
# --------------------------------------------
#
# Crear IP pública para el equilibrador de carga:

Write-Host "Creando IP publica para el LB" -ForegroundColor Black -BackgroundColor Yellow

$publicIP = New-AzPublicIpAddress `
  -ResourceGroupName $ResourceGroupName `
  -Location $Location `
  -AllocationMethod "Static" `
  -Name $PublicLB_IPname
  

# Creación de un equilibrador de carga:
# --------------------------------------
#
# Creamos grupo de direcciones IP de front-end y lo asociamos a la direción IP anterior

Write-Host "Creando LB Front-end y asociandole la IP publica" -ForegroundColor Black -BackgroundColor Yellow

$frontendIP = New-AzLoadBalancerFrontendIpConfig `
  -Name $frontendName `
  -PublicIpAddress $publicIP

# Creamos un grupo de direcciones de back-end al cual se conectarán las VMs:

Write-Host "Creando LB Back-end IP pool para las VMs" -ForegroundColor Black -BackgroundColor Yellow

$backendPool = New-AzLoadBalancerBackendAddressPoolConfig `
  -Name $backendName

#Creamos el equilibrador de carga mediante los grupos de direcciones IP de front-end y back-end creados en los pasos anteriores:

Write-Host "Creando LB con sus Back and Front Ends" -ForegroundColor Black -BackgroundColor Yellow

$lb = New-AzLoadBalancer `
  -ResourceGroupName $ResourceGroupName `
  -Name $LoadBalancerName `
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


Write-Host "Creando Sonda de Estado TCP 80 para el LB" -ForegroundColor Black -BackgroundColor Yellow

Add-AzLoadBalancerProbeConfig `
  -Name $HealthProbeName `
  -LoadBalancer $lb `
  -Protocol http `
  -Port 80 `
  -RequestPath / `
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

Write-Host "Creando regla para LB - equilibra tráfico en puerto TCP 80 y asociar Sondeo" -ForegroundColor Black -BackgroundColor Yellow

$probe = Get-AzLoadBalancerProbeConfig -LoadBalancer $lb -Name $HealthProbeName

Add-AzLoadBalancerRuleConfig `
  -Name $LoadBalancerName `
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

Write-Host "Creando VNET y SubVNET" -ForegroundColor Black -BackgroundColor Yellow

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

Write-Host "Creando NICs para las VMs del LB" -ForegroundColor Black -BackgroundColor Yellow

for ($i=1; $i -le 2; $i++)
{
  
   New-AzNetworkInterface `
     -ResourceGroupName $ResourceGroupName `
     -Name "$vmName$i" `
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

Write-Host "Creando el Grupo de Disponibilidad para las VMs" -ForegroundColor Black -BackgroundColor Yellow

$availabilitySet = New-AzAvailabilitySet `
  -ResourceGroupName $ResourceGroupName `
  -Name $availabilitySetName `
  -Location $Location `
  -Sku aligned `
  -PlatformFaultDomainCount 2 `
  -PlatformUpdateDomainCount 2

# Creamos las VMs:


for ($i=1; $i -le 2; $i++)
{
    Write-Host "Creando VM$i ..." -ForegroundColor Black -BackgroundColor Yellow   
    $vmNameNum = $vmName + $i
    $VNETnameNum = $VNETname + $i
    $SubNETnameNum = $SubNETname + $i
    $PublicIpAddressNameNum = $PublicIpAddressName + $i
 
    # Instalamos el servidor web de IIS y después actualiza la página 
    # Default.htm para mostrar el nombre de host de la máquina virtual:

    $PublicSettings = '{"ModulesURL":"https://github.com/jorgeagudom/lb-dsc-extension-iis-server-windows-vm/raw/master/DSC_IIS_personalizado.ps1.zip", "configurationFunction": "DSC_IIS_personalizado.ps1\\MatIIS", "Properties": {"vmName": '+'"'+$vmNameNum+'"'+'} }'

    New-AzVm `
        -ResourceGroupName $ResourceGroupName `
        -Name $vmNameNum `
        -Location $Location `
        -ImageName $ImageName `
        -VirtualNetworkName $VNETnameNum `
        -SubnetName $SubNETnameNum `
        -OpenPorts 80 `
        -Size $Size `
        -AvailabilitySetName $availabilitySetName `
        -Credential $cred

   Write-Host "VM$i creada con éxito!!" -ForegroundColor Black -BackgroundColor Yellow

   Write-Host "Instalando IIS con DSC en VM$i..." -ForegroundColor Black -BackgroundColor Yellow
   
   Set-AzVMExtension `
     -ExtensionName "DSC" `
     -ResourceGroupName $ResourceGroupName `
     -VMName $vmNameNum `
     -Publisher "Microsoft.Powershell" `
     -ExtensionType "DSC" `
     -TypeHandlerVersion 2.7 `
     -SettingString $PublicSettings `
     -Location $Location 

   Write-Host "Servidor IIS instalado en VM$i con éxito!!" -ForegroundColor Black -BackgroundColor Yellow
}