#region Originating script: '.\DatabaseFunctions.ps1'
<#
.SYNOPSIS
   Returns a new sql connection object with initialized conneciton string
.PARAMETER DbHost
	Represents a valid database host or instance name e.g. MYHOST\SQLINSTANCE
.PARAMETER DbName
	A valid database name on the target server
.PARAMETER ApplicationName
	A optional name how the script application logically appears in the SQL-Server
	Default ApplicationName = "PowerShell Scripting Environment"
.PARAMETER IntegratedSecurity	
	An optional parameter that is $true by default
	Windows Integrated Security is enabled by default
	Set to $false if SQL-Login credentials are required
.PARAMETER SqlLogin	
	A valid sql login username
.PARAMETER SqlLoginPw	
	The password for the sql login username
.EXAMPLE
   SQL-Connection with integrated security
   Get-SqlServerConnection -DbHost "SERVER01\DEV" -DbName "myDatabase"
.EXAMPLE
   SQL-Connection with sql login
   Get-SqlServerConnection -DbHost "SERVER01\DEV" -DbName "myDB" -ApplicationName "MyPSScript" -IntegratedSecurity $false -SqlLogin "sqlUser" -SqlLoginPw "P@ssw0rd!"
#>
function Get-SqlServerConnection() {
	[CmdLetBinding()]
	param(  [parameter(mandatory=$true)][ValidateNotNullOrEmpty()][string]$DbHost
		  , [parameter(mandatory=$true)][ValidateNotNullOrEmpty()][string]$DbName
		  , [parameter(mandatory=$false)][string]$ApplicationName = "PowerShell Scripting Environment"		  
		  , [parameter(mandatory=$false)][bool]$IntegratedSecurity = $true
		  , [parameter(mandatory=$false)][string]$SqlLogin
		  , [parameter(mandatory=$false)][string]$SqlLoginPw
	)
	begin {		
		# Set connection properties
		$connProperties = @{
			'db_host'=$DbHost;
			'db_name'=$DbName;
			'app_name'=$ApplicationName;
			'winnt_logon'=$IntegratedSecurity;
			'sql_login'=$SqlLogin;
			'sql_pw'=$SqlLoginPw;
		}
		
		if (!($connProperties.winnt_logon) -and ([string]::IsNullOrEmpty($connProperties.sql_login) -or [string]::IsNullOrEmpty($connProperties.sql_pw) ) ) { throw "IntegratedSecurity is $false, please provide username and password." }
	}
	process {
		# Create connection string
		$oConnBuilder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
		
		$oConnBuilder['Data Source'] = $connProperties.db_host
		$oConnBuilder['Initial Catalog'] = $connProperties.db_name
		
		if ($connProperties.winnt_logon) {
			$oConnBuilder['Integrated Security'] = "True"
		}
		else {
			$oConnBuilder['User ID'] = $connProperties.sql_login
			$oConnBuilder['Password'] = $connProperties.sql_pw
		}
		
		$oConnBuilder['Max Pool Size'] = "32"
		$oConnBuilder['MultipleActiveResultSets'] = "False"
		$oConnBuilder['Application Name'] = $app_name
		$oConnBuilder['Workstation ID'] = $env:COMPUTERNAME
		
		
		# Create database connection object
		[object]$oSqlConn 	= New-Object System.Data.SqlClient.SqlConnection
		
		# Assign connection string
		$oSqlConn.ConnectionString = $oConnBuilder.ConnectionString
	}
	end { return $oSqlConn }
}


<#
.SYNOPSIS
   Validates a SQL-Server connection
   Returns $true or $false for connection status 
.PARAMETER SqlConnection
	Represents a valid sql database connection from type System.Data.SqlClient.SqlConnection
.EXAMPLE
   SQL-Connection with integrated security
   Check-SqlConnection -SqlConnection $myConnectoinObject
#>
function Test-SqlConnection() {
	[CmdLetBinding()]
	param( [parameter(mandatory=$true)][ValidateNotNullOrEmpty()][System.Data.SqlClient.SqlConnection]$SqlConnection )
	begin {
		[System.Data.SqlClient.SqlConnection]$oSqlConnection = $SqlConnection
		[bool]$ret_val = $false
	}
	process {
			Write-Host "### Initialize SQL-Server connection test..."
			Write-Host " "
			Write-Host "### Your connection string:"
			Write-Host $oSqlConnection.ConnectionString -ForegroundColor DarkYellow 
			Write-Host " " 
			
			try {
				Write-Host "### Try to establish SQL-Server session..."
				$oSqlConnection.Open()
				
				Write-Host ( "### SQL-Server Session State: " + $oSqlConnection.State.ToString() ) -ForegroundColor Yellow
				Write-Host ( "### Running SQL-Server V" + $oSqlConnection.ServerVersion.ToString() ) -ForegroundColor DarkMagenta
				Write-Host ( "### Your ClientConnectionId: " + $oSqlConnection.ClientConnectionId.ToString() ) -ForegroundColor DarkCyan
				Write-Host " "	
				
				Write-Host "### Closing SQL-Server test session..."
				$oSqlConnection.Close()
				
				# Set return value $true
				$ret_val = $true
			}
			catch {
				$errMsg = $_.Exception.Message
				throw $errMsg
			}
	}
	end { return $ret_val }
}


<#
.SYNOPSIS
   Executes an AdHoc statement on a SQL-Server and returns the result as dataset
.PARAMETER DatabaseConnection
	Represents a valid sql database connection from type System.Data.SqlClient.SqlConnection
.PARAMETER SqlStatement
	The select, insert, update, delete or merge statement 
.PARAMETER CommandTimeout
	Sql command timeout
	Default is 15 seconds
.EXAMPLE
	$res = (Invoke-AdHocStatement -DatabaseConnection $DbConnectionObject -SqlStatement "SELECT srv.server_id, srv.name, srv.product FROM sys.servers AS srv;")
	
	$LinkedServers = New-Object System.Data.DataTable
	$LinkedServers = $res.Tables[0]

	$LinkedServers | ForEach-Object { Write-Host ("#" + $_.server_id + " => " + $_.name + " :: " + $_.product) }	
#>
function Invoke-AdHocStatement() {
	[OutputType([System.Data.DataSet])]
	[CmdletBinding()]
	param( [parameter(mandatory=$true, HelpMessage="SQL-Server Connection Object")][ValidateNotNullOrEmpty()][System.Data.SqlClient.SqlConnection]$DatabaseConnection
		, [parameter(mandatory=$true, HelpMessage="Could be a SELECT, INSERT, UPDATE, DELETE sql statement")][ValidateNotNullOrEmpty()][string]$SqlStatement
		, [parameter(mandatory=$false, HelpMessage="SqlCommand timeout")][int]$CommandTimeout=15
	)
	begin {
		[System.Data.SqlClient.SqlConnection]$oDatabaseConnection = $DatabaseConnection

		$local:sqlCmd = $oDatabaseConnection.CreateCommand()
		$local:sqlCmd.CommandType = [System.Data.CommandType]::Text
		$local:sqlCmd.CommandText = $SqlStatement
		$local:sqlCmd.CommandTimeout = $CommandTimeout
	}
	process {
		try {
			$local:DataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($local:sqlCmd)
			$local:ResultSet = New-Object System.Data.DataSet
			$local:DataAdapter.Fill($local:ResultSet)
		}
		catch {
			throw $_.Exception
		}
}
end { return $local:ResultSet }
}

<#
.SYNOPSIS
   Executes a Stored procedure on a SQL-Server and returns the result as dataset
.PARAMETER DatabaseConnection
	Represents a valid sql database connection from type System.Data.SqlClient.SqlConnection
.PARAMETER ProcedureName
	Name of the database stored procedure 
.PARAMETER ProcedureParameters
	A hashtable parameter collection.
	The key of the hash table must be the name of the parameter, without the "@" sign
	Value contains the the content of the procedure parameters
.PARAMETER CommandTimeout
	Sql command timeout
	Default is 15 seconds
.EXAMPLE
	Procedure call without parameters
	$res = (Invoke-StoredProcedure -DatabaseConnection $MyDbConnection -ProcedureName "mgmt.CheckServerHealth")
	
	$HealthData = New-Object System.Data.DataTable
	$HealthData = $res.Tables[0]

	$HealthData | ForEach-Object { Write-Host ("#" + $_.server_id + " => " + $_.name + " :: " + $_.health_state) }	
.EXAMPLE
	Procedure call with regular parameters
	
	[System.Collections.Hashtable]$db_proc_params = @{ int_val=6; str_val="check" }
	$res = ( Invoke-StoredProcedure -DatabaseConnection $myConnection -ProcedureName $db_proc -ProcedureParameters $db_proc_params)
	
	$HealthData = New-Object System.Data.DataTable
	$HealthData = $res.Tables[0]

	$HealthData | ForEach-Object { Write-Host ("#" + $_.server_id + " => " + $_.name + " :: " + $_.health_state) }
.EXAMPLE
	Procedure call, where input parameter is a table type
	
	$TestTable = New-Object System.Data.DataTable
	[void]$TestTable.Columns.Add("id", [int64])	
	[void]$TestTable.Columns.Add("value", [string])
	[void]$TestTable.Rows.Add(1, "Check1", 0)
	[void]$TestTable.Rows.Add(2, "Check2", 1)
	
	[System.Collections.Hashtable]$db_proc_params2 = @{ input_table=$TestTable }	
	$res = ( Invoke-StoredProcedure -DatabaseConnection $myConnection -ProcedureName $db_proc -ProcedureParameters $db_proc_params)
	
	$HealthData = New-Object System.Data.DataTable
	$HealthData = $res.Tables[0]

	$HealthData | ForEach-Object { Write-Host ("#" + $_.server_id + " => " + $_.name + " :: " + $_.health_state) }	
#>
function Invoke-StoredProcedure() {
	[OutputType([System.Data.DataSet])]
	[CmdLetBinding()]
	param(  [parameter(mandatory=$true, HelpMessage="SQL-Server Connection Object")][ValidateNotNullOrEmpty()][System.Data.SqlClient.SqlConnection]$DatabaseConnection
		  , [parameter(mandatory=$true, HelpMessage="Stored Procedure Name")][ValidateNotNullOrEmpty()][string]$ProcedureName
		  , [parameter(mandatory=$false, HelpMessage="Procedure parameter hash table collection")][ValidateNotNullOrEmpty()][System.Collections.Hashtable]$ProcedureParameters
		  , [parameter(mandatory=$false, HelpMessage="SqlCommand timeout")][int]$CommandTimeout=15		  
	)
	begin {
		[System.Data.SqlClient.SqlConnection]$local:DbCon = $DatabaseConnection

		$local:sqlCmd = $local:DbCon.CreateCommand()
		$local:sqlCmd.CommandType = [System.Data.CommandType]::StoredProcedure	
		$local:sqlCmd.CommandText = $ProcedureName
		$local:sqlCmd.CommandTimeout = $CommandTimeout		
		
		if($ProcedureParameters) { 
			[bool]$HasParams = $true 
			[System.Collections.Hashtable]$local:sqlParams = $ProcedureParameters
		}
	}
	process {
		try {
			# Add required parameters
			if($HasParams) {
				$local:sqlParams.GetEnumerator() | %{ $param_name = ( "@" + $_.Key )
													$local:sqlCmd.Parameters.AddWithValue($param_name, $_.Value)
				}
			}
			$local:DataAdapter = New-Object System.Data.SqlClient.SqlDataAdapter($local:sqlCmd)
			$local:ResultSet = New-Object System.Data.DataSet
			$local:DataAdapter.Fill($local:ResultSet)	
		} catch {
				throw $_.Exception		
		}
	}
	end { return $local:ResultSet }
}

#endregion Originating script: '.\DatabaseFunctions.ps1'

