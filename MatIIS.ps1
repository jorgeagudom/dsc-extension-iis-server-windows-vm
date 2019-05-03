Configuration MatIIS
{
  param ($VM)

  Node $VM
  {
    #Instala el rol de IIS
    WindowsFeature IIS
    {
      Ensure = “Present”
      Name = “Web-Server”
    }
  }
} 