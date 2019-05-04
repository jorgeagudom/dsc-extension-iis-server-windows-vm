Configuration MatIIS
{
  param ($vmName)

  Node $vmName
  {
     #I nstall the IIS Role

    WindowsFeature IIS
    {
      Ensure = "Present"
      Name = "Web-Server"
    }

    # Crea el index.html de cada VM

    File ArchivoIndex
    {
      Type = "File"
      DestinationPath = "c:\inetpub\wwwroot\index.html"
      Contents = "<H1> Estas viendo la web de $vmName </H1>"
      Ensure = "Present"
    }  

  }
} 