# lb-dsc-extension-iis-server-windows-vm
Desplegar en Azure mediante un Script de PowerShell un Grupo de Disponibilidad que ogrece un Servicio Web cuya carga distribute un Balanceador de Carga. 

El propio script llama a un DSC para llevar a cabo la instalacion de el IIS personalizado para cada VM.

Por defecto se crean 2 maquinas Windows Server 2016 Datacenter Core de tamaño Standar_BS2, pero todo esto se puede modificar cambiando las variables en las primeras lineas del Script.
