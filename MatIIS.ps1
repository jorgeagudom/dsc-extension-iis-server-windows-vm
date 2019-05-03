Configuration MatIIS
{
  param ($vmName)

  Node $vmName
  {
    #Install the IIS Role
    WindowsFeature IIS
    {
      Ensure = "Present"
      Name = "Web-Server"
    }  
  }
} 