Configuration InstalarIIS
{
    node "localhost"
    {
        WindowsFeature IIS
        {
          Ensure = "Present"
          Name = "Web-Server"
          IncludeAllSubFeature = $true
        }
        
        File ArchivoIndex
        {
          Type = "File"
          DestinationPath = "c:\inetpub\wwwroot\index.html"
          Contents = "<H1> 'Estas viendo la web de MAT.com'</H1>"
          Ensure = "Present"
         }
    }
}
