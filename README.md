# DatabaseFunctions - A common PowerShell Module for accessing MS SQL-Server
PowerShell DatabaseFunctions Module

# About
Hey Guys... long time ago since i've posted something here. The next thing i want to share with the community is a nice and small module, that makes every admin and powershell user happy :)

A powershell module for accessing sql server databases easily. There are always a few steps to prepare bevore accessing a database. i want to have it more faster. That was the reason for this module. It uses only the default .NET libraries, shipped with any windows server. There are no 3rd pary modules or frameworks required. 

# Function overview
The powershell module contains just four generic functions:

* `Get-SqlServerConnection()`
* `Test-SqlConnection()`
* `Invoke-AdHocStatement()`
* `Invoke-StoredProcedure()`

## Sample
But they are very powerful and safe, if you use it in combination, together. I will give you a quick example here
```PowerShell
Import-Module DatabaseFunctions -Verbose 
 
$myConnection = ( Get-SqlServerConnection -DbHost "SERVER\INSTANCE" -DbName "master" -IntegratedSecurity $true ) 
 
if ((Test-SqlConnection -SqlConnection $myConnection) -eq $true) {  
    [string]$query = "SELECT d.name as db_name FROM sys.databases AS d;" 
 
    $res = ( Execute-AdHocStatement -DatabaseConnection $myConnection -SqlStatement $query ) 
 
    $Databases = New-Object System.Data.DataTable 
    $Databases = $res.Tables[0] 
 
    $Databases | ForEach-Object { Write-Host ("### ->" + $_.db_name) } 
} else { 
    throw "No database connection possible!" 
} 
```
