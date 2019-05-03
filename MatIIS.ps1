Configuration MatIIS
{
  param ($VMname)

  Node $VMname
  {
    #Instala el rol de IIS
    WindowsFeature IIS
    {
      Ensure = “Present”
      Name = “Web-Server”
    }
  }
} 