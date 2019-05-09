# ----------------------------
# CREACIÓN DE LOAD BALANCER
# ----------------------------

# Variables:

$ResourceGroupName = "RG-MatWebServer"
$Location = "eastus2"

$PublicLB_IPname = "WebEmpresaIP"
#$PublicIpAddressName = "WebServerPublicIP"

$frontendName = "LbFrontEndPool"
$backendName = "LbBackEndPool"
$LoadBalancerName = "WebLoadBalancer"
$HealthProbeName = "LbHealthProbe80"
#$LbRuleName = "LoadBalancerRule" podría ponerlo y probar, pero de momento no

$VNETname = "LbVNet"
$SubNETname = "LbSubVNet"

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

#/////////////////////////////
#/////////////////////////////
#/////////////////////////////


$probe = New-AzLoadBalancerProbeConfig `
  -Name $HealthProbeName `
  -RequestPath / `
  -Protocol http `
  -Port 80 `
  -IntervalInSeconds 15 `
  -ProbeCount 2

$lbrule = New-AzLoadBalancerRuleConfig `
  -Name "myLoadBalancerRule" `
  -FrontendIpConfiguration $frontendIP `
  -BackendAddressPool $backendPool `
  -Protocol Tcp `
  -FrontendPort 80 `
  -BackendPort 80 `
  -Probe $probe

$NATrule1 = New-AzLoadBalancerInboundNatRuleConfig `
-Name 'myLoadBalancerRDP1' `
-FrontendIpConfiguration $frontendIP `
-Protocol tcp `
-FrontendPort 4221 `
-BackendPort 3389

$NATrule2 = New-AzLoadBalancerInboundNatRuleConfig `
-Name 'myLoadBalancerRDP2' `
-FrontendIpConfiguration $frontendIP `
-Protocol tcp `
-FrontendPort 4222 `
-BackendPort 3389


#/////////////////////////////
#/////////////////////////////
#/////////////////////////////

#Creamos el equilibrador de carga mediante los grupos de direcciones IP de front-end y back-end creados en los pasos anteriores:

Write-Host "Creando LB ....." -ForegroundColor Black -BackgroundColor Yellow

$lb = New-AzLoadBalancer `
  -ResourceGroupName $ResourceGroupName `
  -Name $LoadBalancerName `
  -Location $Location `
  -FrontendIpConfiguration $frontendIP `
  -BackendAddressPool $backendPool `
  -Probe $probe `
  -LoadBalancingRule $lbrule `
  -InboundNatRule $natrule1,$natrule2

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

# CREACIÓN NSG y las Reglas:
# --------------------------
# --------------------------

# Create a "NSG Rule" for port 3389:
# ---------------------------------------------------

$rule1 = New-AzNetworkSecurityRuleConfig `
-Name 'myNetworkSecurityGroupRuleRDP' `
-Description 'Allow RDP' `
-Access Allow `
-Protocol Tcp `
-Direction Inbound `
-Priority 1000 `
-SourceAddressPrefix Internet `
-SourcePortRange * `
-DestinationAddressPrefix * `
-DestinationPortRange 3389

# Create a "NSG Rule" for port 80:
# ---------------------------------------------------

$rule2 = New-AzNetworkSecurityRuleConfig `
-Name 'myNetworkSecurityGroupRuleHTTP' `
-Description 'Allow HTTP' `
-Access Allow `
-Protocol Tcp `
-Direction Inbound `
-Priority 2000 `
-SourceAddressPrefix Internet `
-SourcePortRange * `
-DestinationAddressPrefix * `
-DestinationPortRange 80

# Creación NSG:
# ----------------

$nsg = New-AzNetworkSecurityGroup `
-ResourceGroupName $ResourceGroupName `
-Location $Location `
-Name 'myNetworkSecurityGroup' `
-SecurityRules $rule1,$rule2
  
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

# Creamos las NIC virtuales para las próximas VMs:

Write-Host "Creando NICs para las VMs del LB" -ForegroundColor Black -BackgroundColor Yellow

$a=1

$nicVM1 = New-AzNetworkInterface `
    -ResourceGroupName $ResourceGroupName `
    -Name "$vmName$a" `
    -Location $Location `
    -NetworkSecurityGroup $nsg `
    -LoadBalancerInboundNatRule $NATrule1 `
    -Subnet $vnet.Subnets[0] `
    -LoadBalancerBackendAddressPool $lb.BackendAddressPools[0]

$b=2

$nicVM2 = New-AzNetworkInterface `
    -ResourceGroupName $ResourceGroupName `
    -Name "$vmName$b" `
    -Location $Location `
    -NetworkSecurityGroup $nsg `
    -LoadBalancerInboundNatRule $NATrule2 `
    -Subnet $vnet.Subnets[0] `
    -LoadBalancerBackendAddressPool $lb.BackendAddressPools[0]


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
   
    New-AzVm `
        -ResourceGroupName $ResourceGroupName `
        -Name $vmNameNum `
        -Location $Location `
        -ImageName $ImageName `
        -VirtualNetworkName $VNETname `
        -SubnetName $SubNETname `
        -SecurityGroupName "myNetworkSecurityGroup" `
        -OpenPorts 80 `
        -Size $Size `
        -AvailabilitySetName $availabilitySetName `
        -Credential $cred `
        -AsJob

   Write-Host "Creando VM$i ...revisa estado en el portal" -ForegroundColor Black -BackgroundColor Yellow

}
