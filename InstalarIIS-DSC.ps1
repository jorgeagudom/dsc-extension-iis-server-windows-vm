Configuration InstalarIIS
{
    node "localhost"
    {
        WindowsFeature IIS
        {
        Ensure = "Present"
        Name = "Web-Server"
        }
    }
}