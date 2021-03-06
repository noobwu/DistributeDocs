<#
    .SYNOPSIS
       Replace Token

    .DESCRIPTION
        设置日志
#>
function SetLoggergingVariables
{

    #Already setup
    if ($Script:Loggerging -and $Script:LevelNames)
    {
        return
    }

    Write-Verbose -Message 'Setting up vars'

    $Script:NOTSET = 0
    $Script:DEBUG = 10
    $Script:INFO = 20
    $Script:WARNING = 30
    $Script:ERROR_ = 40

    New-Variable -Name LevelNames           -Scope Script -Option ReadOnly -Value ([hashtable]::Synchronized(@{
                $NOTSET   = 'NOTSET'
                $ERROR_   = 'ERROR'
                $WARNING  = 'WARNING'
                $INFO     = 'INFO'
                $DEBUG    = 'DEBUG'
                'NOTSET'  = $NOTSET
                'ERROR'   = $ERROR_
                'WARNING' = $WARNING
                'INFO'    = $INFO
                'DEBUG'   = $DEBUG
            }))
    #$curRunDirPath=$PSScriptRoot
    #$localHost = [System.Environment]::MachineName

    #New-Variable -Name ScriptRoot           -Scope Script -Option ReadOnly -Value ([System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Module.Path))
    if ($null -eq $ScriptRoot)
    {
        New-Variable -Name ScriptRoot           -Scope Script -Option ReadOnly -Value ([System.IO.Path]::GetDirectoryName($PSScriptRoot))
    }
    New-Variable -Name Defaults             -Scope Script -Option ReadOnly -Value @{
        Level       = $LevelNames[$LevelNames['NOTSET']]
        LevelNo     = $LevelNames['NOTSET']
        Format      = '[%{timestamp:+%Y-%m-%d %T%Z}] [%{level:-7}] %{message}'
        Timestamp   = '%Y-%m-%d %T%Z'
        CallerScope = 1
    }

    New-Variable -Name Loggerging   -Scope Script -Option ReadOnly -Value ([hashtable]::Synchronized(@{
                Level       = $Defaults.Level
                LevelNo     = $Defaults.LevelNo
                Format      = $Defaults.Format
                CallerScope = $Defaults.CallerScope
            }))
}

<#
    .SYNOPSIS
       Replace Token

    .DESCRIPTION
        This function Replace Token

    .PARAMETER String
        String
        
    .PARAMETER Source
        Source

    .EXAMPLE
        PS C:\> Replace-Token 'Hello, World!'

    .LINK
        https://logging.readthedocs.io/en/latest/functions/Write-Logger.md

#>
function ReplaceToken
{
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '')]
    [CmdletBinding()]
    param(
        [string] $String,
        [object] $Source
    )

    [string] $result = $String
    [regex] $tokenMatcher = '%{(?<token>\w+?)?(?::?\+(?<datefmtU>(?:%[ABCDGHIMRSTUVWXYZabcdeghjklmnprstuwxy].*?)+))?(?::?\+(?<datefmt>(?:.*?)+))?(?::(?<padding>-?\d+))?}'
    $tokenMatches = @()
    $tokenMatches += $tokenMatcher.Matches($String)

    [array]::Reverse($tokenMatches)
    #Write-Verbose "String:$($result)" -Verbose
    #Write-Verbose "Source:$($Source | ConvertTo-Json -Compress)" -Verbose
    #Write-Verbose "tokenMatcher:$($tokenMatcher | ConvertTo-Json -Compress)" -Verbose
    foreach ($match in $tokenMatches)
    {
        $formattedEntry = [string]::Empty
        $tokenContent = [string]::Empty

        $token = $match.Groups["token"].value
        $datefmt = $match.Groups["datefmt"].value
        $datefmtU = $match.Groups["datefmtU"].value
        $padding = $match.Groups["padding"].value

        [hashtable] $dateParam = @{ }
        if (-not [string]::IsNullOrWhiteSpace($token))
        {
            $tokenContent = $Source.$token
            $dateParam["Date"] = $tokenContent
        }

        if (-not [string]::IsNullOrWhiteSpace($datefmtU))
        {
            $formattedEntry = Get-Date @dateParam -UFormat $datefmtU
        }
        elseif (-not [string]::IsNullOrWhiteSpace($datefmt))
        {
            $formattedEntry = Get-Date @dateParam -Format $datefmt
        }
        else
        {
            $formattedEntry = $tokenContent
        }

        if ($padding)
        {
            $formattedEntry = "{0,$padding}" -f $formattedEntry
        }

        $result = $result.Substring(0, $match.Index) + $formattedEntry + $result.Substring($match.Index + $match.Length)
    }

    return $result
}

<#
    .DESCRIPTION
       控制台输出日志

    .PARAMETER level
        日志类型(VERBOSE,DEBUG, INFO, WARNING, ERROR)

    .PARAMETER message
        日志内容

    .EXAMPLE
        PS C:\> Logger -Level ERROR -Message 'Hello, World!'

#>
function Logger
{
    [CmdletBinding()]
    param(
        #日志级别
        [ValidateSet("VERBOSE", "DEBUG", "INFO", "WARNING", "ERROR")]
        [string] $level,
        #日志信息
        [string] $message
    )
    if ($null -ne $level)
    {
        $level = 'DEBUG' 
    }
    $colorMapping = @{
        'DEBUG'   = 'Blue'
        'INFO'    = 'Green'
        'WARNING' = 'Yellow'
        'ERROR'   = 'Red'
    }
    $callerScope = 1
    #调用方法的堆栈信息(如所在行，方法名)
    $callStack = (Get-PSCallStack)[$callerScope] 
    $log = [hashtable] @{
        timestamp    = [datetime]::now
        timestamputc = [datetime]::UtcNow
        level        = $level
        lineno       = $callStack.ScriptLineNumber
        pathname     = $callStack.ScriptName
        filename     = $fileName
        caller       = $callStack.Command
        message      = $message
        pid          = $PID
        host         = [system.environment]::MachineName
        username     = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    }

    $logText = ReplaceToken -String "[%{timestamp:+%Y-%m-%d %T%Z}] [%{level:-7}]  [%{caller}]  [%{lineno}] %{message}" -Source $log
    #$logText = ($Log | ConvertTo-Json -Compress)
    if ($colorMapping.ContainsKey($level))
    {
        $Host.UI.WriteLine($colorMapping[$level], $Host.UI.RawUI.BackgroundColor, $logText)
    }
    else
    {
        $Host.UI.WriteLine($logText)
    }
    $Host.UI.WriteLine($($Logger | ConvertTo-Json -Compress))
}
<#
    .DESCRIPTION
       如果文件夹不存在则创建

    .PARAMETER dirPath
        文件夹路径
        

    .EXAMPLE
      PS C:\> CreateDir $dirPath
#> 
function CreateDir
{
    [CmdletBinding()]
    param(
        [string] $dirPath
    )
    
    # Logger DEBUG("dirPath:`"$dirPath`"")

    if ((Test-Path -Path $dirPath))
    {
        return
    }

    New-Item $dirPath -Type Directory
}

<#
    .DESCRIPTION
       复制文件夹中所有文件及子文件夹

    .PARAMETER sourcePath
        源文件夾目錄
        
    .PARAMETER desFolder
        目標文件夹目录
    
    .EXAMPLE
      PS C:\> CopyFolder $mqPaths
#> 
function CopyFolder
{
    param
    (
        #源文件或者文件夹地址
        [string] 
        $sourcePath,
        #目标文件或者文件夹地址
        [string] 
        $desFolder
    )
    $sourcePath = [System.IO.Path]::Combine($sourcePath, "*")
      

    if (!(Test-Path -Path $sourcePath))
    {
        log WARNING("CopyFolder  Folder   `"$sourcePath`" no exists.")
        return			
    }
    if (!(Test-Path -Path $desFolder))
    {
        New-Item $desFolder -Type Directory
        if (!(Test-Path -Path $desFolder))
        {
            return
        }
    }
    Logger INFO("复制`"$sourcePath`" 下的所有文件及子文件夹到 `"$desFolder`" 开始...")	

    Copy-Item -Path $sourcePath -Destination $desFolder -Recurse  -Force

    Logger INFO("复制`"$sourcePath`" 下的所有文件及子文件夹到 `"$desFolder`" 结束.")	

}

#复制文件或者文件夹
<#
    .DESCRIPTION
       复制文件或者文件夹

    .PARAMETER sourcePath
        源文件夾目錄
        
    .PARAMETER desFolder
        目標文件夹目录
    
    .EXAMPLE
      PS C:\> CopyFolder $mqPaths
#> 
function CopyOneItem
{
    param
    (
        #源文件或者文件夹地址
        [string] 
        $sourcePath,
        #目标文件或者文件夹地址
        [string] 
        $desFolder
    )
    if (!(Test-Path -Path $sourcePath))
    {
        Logger WARNING("CopyOneItem  file   `"$sourcePath`" no exists.")
        return			
    }
    if (!(Test-Path -Path $desFolder))
    {
        New-Item $desFolder -Type Directory
        if (!(Test-Path -Path $desFolder))
        {
            return
        }
    }
    # Logger  DEBUG("Copy directory from `"$sourcePath`"  start.")	

    if ($sourcePath -is [System.IO.DirectoryInfo])
    {
        CopyFolder -sourcePath $sourcePath -desFolder $desFolder
    }
    else
    {
        Copy-Item -Path $sourcePath -Destination $desFolder -Force
        # Logger INFO("Copy file from  `"$sourcePath`" to `"$desFolder`" successfully.")			 
    }
}
 
<#
    .DESCRIPTION
       清空指定目录下的所有文件

    .PARAMETER Level
        日志类型(VERBOSE,DEBUG, INFO, WARNING, ERROR)
        
    .EXAMPLE
      PS C:\> ClearMqData @("D:\Tools\MQ\ActiveMQ-Cluster\LB\apache-activemq-61716")
    
#>
function ClearDir
{
    [CmdletBinding()]
    param(
        # 目录地址
        [string] $path
    )
    If (([String]::IsNullOrEmpty($path)))
    {
        throw "路径不能为空"
    }
    if (!(Test-Path -Path $path))
    {
        throw "路径地址[`($path)`]不存在"
    } 

    #清空$path下的文件夹及文件
    Get-ChildItem -Path $path -Recurse -Force | Remove-Item -Recurse -Force
    
    Logger WARNING("清空 `"$path`"  中的文件夹及文件.")
    
}

<#
    .DESCRIPTION
       清空 ActiveMQ 目录下的 data 目录的内容

    .PARAMETER Level
        日志类型(VERBOSE,DEBUG, INFO, WARNING, ERROR)
        
    .EXAMPLE
      PS C:\> ClearMqData @("D:\Tools\MQ\ActiveMQ-Cluster\LB\apache-activemq-61716")

#>
function ClearMqData
{
    [CmdletBinding()]
    param(
        # ActiveMQ 所在目录
        [string] $mqPath
    )
    If (([String]::IsNullOrEmpty($mqPath)))
    {
        throw "路径不能为空"
    }
    if (!(Test-Path -Path $mqPath))
    {
        throw "路径地址[`($mqPath)`]不存在"
    } 
    $dataPath = -Join ($mqPath, '\data')
    ClearDir -path $dataPath
}


<#
    .DESCRIPTION
       复制 ActiveMQ 的配置文件到指定目录

    .PARAMETER sourcePath
       来源目录

    .PARAMETER destPath
       目的地目录
        
    .EXAMPLE
      PS C:\> CopyMqConfig 
    
#>
function CopyMqConfig
{
    [CmdletBinding()]
    param(
        # ActiveMQ 来源目录
        [string]$sourcePath,
        # ActiveMQ 目标目录
        [string]$destPath
    )
    If (([String]::IsNullOrEmpty($sourcePath)))
    {
        throw "目录地址不能为空"
    }
    if (!(Test-Path -Path $sourcePath))
    {
        throw "目录地址[`($sourcePath)`]不存在"
    } 
    # ActiveMQ 启动配置文件
    # D:\Tools\MQ\ActiveMQ-Cluster\LB\apache-activemq-hub-61711\bin\win64\wrapper.conf
    $srcWrapperConfigPath = Join-Path -Path $sourcePath -ChildPath "bin\win64\wrapper.conf"
    $destWrapperConfigDir = -Join ($destPath, '\bin\win64')
    #Logger INFO("ActiveMQ 启动配置文件, src:`"$srcWrapperConfigPath`",dest:`"$destWrapperConfigDir`" .")

    CopyOneItem -sourcePath $srcWrapperConfigPath -desFolder  $destWrapperConfigDir


    #  D:\Tools\MQ\ActiveMQ-Cluster\LB\apache-activemq-hub-61711\conf\activemq.xml
    # ActiveMQ 配置文件
    $srcActiveMqConfigPath = Join-Path -Path $sourcePath  -ChildPath "conf\activemq.xml"
    $destActiveMqConfigDir = -Join ($destPath, '\conf')
    CopyOneItem -sourcePath $srcActiveMqConfigPath -desFolder  $destActiveMqConfigDir


    # D:\Tools\MQ\ActiveMQ-Cluster\LB\apache-activemq-hub-61711\conf\jetty.xml
    # ActiveMQ 后台管理配置文件
    $srcJettyConfigPath = Join-Path -Path $sourcePath -ChildPath "conf\jetty.xml"
    $destJettyConfigDir = -Join ($destPath, '\conf')
    CopyOneItem -sourcePath $srcJettyConfigPath -desFolder  $destJettyConfigDir

}

<# 
    ActiveMQ 配置信息
 #>
class ActiveMQConfig
{
    # 模板目录 D:\Projects\Github\NoobWu\DistributeDocs\ActiveMQ\Cluster\LB\apache-activemq-broker-template
    [string]$TemplatePath

    # 目标文件夹  D:\Projects\Github\NoobWu\DistributeDocs\ActiveMQ\Cluster\LB\apache-activemq-61716
    [string]$BrokerPath 

    # Broker名称 ActiveMQ-LB-61716
    [string]$BrokerName

    # Broker端口 61716
    [string]$BrokerPort

    # Broker 网络连接地址 static:(tcp://127.0.0.1:61711,tcp://127.0.0.1:61712)
    [string]$HubBrokerUri

    # http://activemq.apache.org/networks-of-brokers.html
    # NetworkConnector（网络连接器）
    [string]$NetworkConnectors 

    # Broker管理后台端口 8176
    [int]$JettyPort

    [string]ToString()
    {
        return ("TemplatePath:{0},BrokerPath:{1},BrokerName:{2},BrokerPort:{3},HubBrokerUri:{4},JettyPort:{5}" -f $this.TemplatePath, $this.BrokerPath, $this.BrokerName, $this.BrokerPort, $this.HubBrokerUri, $this.JettyPort)
    }

}

<#
    .DESCRIPTION
       根据模板文件创建 ActiveMQ 配置文件

    .PARAMETER config
        配置信息
        
    .EXAMPLE
      PS C:\> ClearMqData @("D:\Tools\MQ\ActiveMQ-Cluster\LB\apache-activemq-61716")
    
    .EXAMPLE
      $mqConfig = [ActiveMQConfig]::new()
      $mqConfig.BrokerName="ActiveMQ-LB-61719"
      $mqConfig.BrokerPort=61719
      $mqConfig.BrokerPath="D:\Projects\Github\NoobWu\DistributeDocs\ActiveMQ\Cluster\LB\apache-activemq-61716"
      $mqConfig.JettyPort=8171
      $mqConfig.HubBrokerUri="static:(tcp://127.0.0.1:61711,tcp://127.0.0.1:61712)"
      $mqConfig.TemplatePath= "D:\Projects\Github\NoobWu\DistributeDocs\ActiveMQ\Cluster\LB\apache-activemq-template"

      # Logger DEBUG($mqConfig)
    
      PS C:\> CreateMqConfig $mqConfig
#>
function CreateMqConfig
{
    [CmdletBinding()]
    param(
        # ActiveMQ 配置信息
        [ActiveMQConfig] $config
    )
    if ($null -eq $config)
    {
        Logger ERROR("ActiveMQ 配置信息不能为空")
        return;
    }

    # Logger DEBUG($config)
    

    CreateDir ( -Join ($config.BrokerPath, '\bin\win64') )
    CreateDir ( -Join ($config.BrokerPath, '\conf') )

    $srcWrapperConfigPath = Join-Path -Path $config.TemplatePath -ChildPath "bin\win64\wrapper.conf"
    $destWrapperConfigPath = Join-Path -Path $config.BrokerPath -ChildPath "bin\win64\wrapper.conf"

    (Get-Content $srcWrapperConfigPath) | ForEach-Object {
        $_ -replace '{{BrokerName}}', $config.BrokerName `
    } | Set-Content $destWrapperConfigPath


    $srcActiveMQConfigPath = Join-Path -Path $config.TemplatePath -ChildPath "conf\activemq.xml"
    $destActiveMQConfigPath = Join-Path -Path $config.BrokerPath -ChildPath "conf\activemq.xml"

    (Get-Content $srcActiveMQConfigPath -Encoding UTF8) | ForEach-Object {
        $_ -replace '{{BrokerName}}', $config.BrokerName `
            -replace '{{BrokerPort}}', $config.BrokerPort `
            -replace '{{NetworkConnectors}}', $config.NetworkConnectors `
    } | Set-Content $destActiveMQConfigPath -Encoding UTF8
 
    $srcJettyConfigPath = Join-Path -Path $config.TemplatePath -ChildPath "conf\jetty.xml"
    $destJettyConfigPath = Join-Path -Path $config.BrokerPath -ChildPath "conf\jetty.xml"

    (Get-Content $srcJettyConfigPath -Encoding UTF8) | ForEach-Object {
        $_ -replace '{{BrokerName}}', $config.BrokerName `
            -replace '{{JettyPort}}', $config.JettyPort `
    } | Set-Content $destJettyConfigPath -Encoding UTF8

}

<#
    .DESCRIPTION
       初始化 ActiveMQ 配置信息

    .PARAMETER clearData
        是否清除 data 数据
        
    .EXAMPLE
      PS C:\> IniteMqConfigs -clearData $false

     .EXAMPLE
      PS C:\> IniteMqConfigs -clearData $true
#>
function InitLoadBalanceMqConfigs
{
    [CmdletBinding()]
    param(
        # ActiveMQ 配置信息
        [Boolean] $clearData = $false
    )
    #$mqClusterSourcePath = "D:\Projects\Github\NoobWu\DistributeDocs\ActiveMQ\Cluster"
    $mqClusterSourcePath = "F:\Projects\NoobWu\DistributeDocs\ActiveMQ\Cluster"
    $mqClusterDestPath = "D:\Tools\MQ\ActiveMQ-Cluster"
    $templatePath = -Join ($mqClusterSourcePath, "\LB\apache-activemq-template")


    Logger INFO("开始，初始化`【$templatePath`】配置信息 ")
    $hubBrokerCount = 2;
    [ActiveMQConfig[]]$hubMqConfigs = [ActiveMQConfig[]]::new($hubBrokerCount)

    #region  集线 Broker（给生产者使用）
    $hubMqConfigs[0] = [ActiveMQConfig]::new()
    $hubMqConfigs[0].BrokerName = "ActiveMQ-LB-Hub-61711"
    $hubMqConfigs[0].BrokerPort = 61711
    $hubMqConfigs[0].BrokerPath = -Join ($mqClusterSourcePath, "\LB\apache-activemq-hub-61711")
    #网络连接器设置  http://activemq.apache.org/networks-of-brokers.html
    $hubMqConfigs[0].NetworkConnectors = ( -Join ("<networkConnectors>", "`n", '            <networkConnector uri="static:(tcp://127.0.0.1:61712,tcp://127.0.0.1:61716,tcp://127.0.0.1:61717,tcp://127.0.0.1:61718)" duplex="true" />', "`n", "        </networkConnectors>")  )
    $hubMqConfigs[0].JettyPort = 8171
    $hubMqConfigs[0].TemplatePath = $templatePath

    $hubMqConfigs[1] = [ActiveMQConfig]::new()
    $hubMqConfigs[1].BrokerName = "ActiveMQ-LB-Hub-61712"
    $hubMqConfigs[1].BrokerPort = 61712
    $hubMqConfigs[1].BrokerPath = -Join ($mqClusterSourcePath, "\LB\apache-activemq-hub-61712")
    #网络连接器设置  http://activemq.apache.org/networks-of-brokers.html
    $hubMqConfigs[1].NetworkConnectors = ( -Join ("<networkConnectors>", "`n", '            <networkConnector uri="static:(tcp://127.0.0.1:61716,tcp://127.0.0.1:61717,tcp://127.0.0.1:61718)" duplex="true"  />', "`n", "          </networkConnectors>")  )
    $hubMqConfigs[1].JettyPort = 8172
    $hubMqConfigs[1].TemplatePath = $templatePath

    foreach ($config in  $hubMqConfigs)
    {
        # 根据模板创建配置信息
        CreateMqConfig $config 

        # 复制配置信息
        CopyMqConfig  -sourcePath $config.BrokerPath -destPath $config.BrokerPath.Replace($mqClusterSourcePath, $mqClusterDestPath)

        if ($clearData -eq $true)
        {
            #清除 data 数据
            ClearMqData -mqPath $config.BrokerPath.Replace($mqClusterSourcePath, $mqClusterDestPath)
        }
    }  

    #endregion 集线 Broker（给生产者使用）
   
	

    #region  消费Broker（给消费者使用）
    $brokerCount = 3;
    [ActiveMQConfig[]]$mqConfigs = [ActiveMQConfig[]]::new($brokerCount)
    $brokerPort = 61716
    $jettyPort=8176
    for ($i = 0; $i -lt $brokerCount; $i++)
    {
        $mqConfigs[$i] = [ActiveMQConfig]::new()
        $mqConfigs[$i].BrokerPort = ($brokerPort + $i)
        $mqConfigs[$i].BrokerName = "ActiveMQ-LB-" + $mqConfigs[$i].BrokerPort
        $mqConfigs[$i].BrokerPath = -Join ($mqClusterSourcePath, "\LB\apache-activemq-" + $mqConfigs[$i].BrokerPort)
        #网络连接器设置  http://activemq.apache.org/networks-of-brokers.html
        $hubMqConfigs[1].NetworkConnectors = ""
        $mqConfigs[$i].JettyPort = ( $jettyPort + $i)
        $mqConfigs[$i].TemplatePath = $templatePath
    }

    foreach ($config in $mqConfigs)
    {
        # 根据模板创建配置信息
        CreateMqConfig $config 

        #复制配置信息
        CopyMqConfig  -sourcePath $config.BrokerPath -destPath $config.BrokerPath.Replace($mqClusterSourcePath, $mqClusterDestPath)

        if ($clearData -eq $true)
        {
            # 清除 data 数据
            ClearMqData -mqPath $config.BrokerPath.Replace($mqClusterSourcePath, $mqClusterDestPath)
        }
    }  
    
    #endregion


    Logger INFO("完成，初始化`【$templatePath`】配置信息 ")
   
}

#InitMqConfigs -clearData $true


<# 
    ActiveMQ  配置信息(Zookeeper配置主)
 #>
class ActiveMQZookeeperConfig:ActiveMQConfig
{
    #同一个主从 Broker的名称一定要一样
    [string]$ClusterBrokerName
     
    # 复本数量 2
    [int]$Replicas

    # 绑定端口 61626
    [int]$BindPort

    #Zookeeper 配置信息 127.0.0.1:2181,127.0.0.1:2182,127.0.0.1:2183
    [string]$ZkAddress

    #Zookeeper 密码 ""
    [string]$ZkPassword

    #BrockerHostName Broker服务器名称
    [string]$BrockerHostName

    #Sync   local_disk
    [string]$Sync

    #ZkPath   /activemq/ha/leveldb-stores
    [string]$ZkPath
}

<#
    .DESCRIPTION
       根据模板文件创建 ActiveMQ 配置文件

    .PARAMETER config
        配置信息
        
    .EXAMPLE
      $mqConfig = [ZookeeperActiveMQConfig]::new()
      $mqConfig.BrokerName="ActiveMQ-LB-61719"
      $mqConfig.BrokerPort=61719
      $mqConfig.BrokerPath="D:\Projects\Github\NoobWu\DistributeDocs\ActiveMQ\Cluster\LB\apache-activemq-61716"
      $mqConfig.JettyPort=8171
      $mqConfig.HubBrokerUri="static:(tcp://127.0.0.1:61711,tcp://127.0.0.1:61712)"
      $mqConfig.TemplatePath= "D:\Projects\Github\NoobWu\DistributeDocs\ActiveMQ\Cluster\LB\apache-activemq-template"

      # Logger DEBUG($mqConfig)
    
      PS C:\> CreateMqConfigForZookeepper $mqConfig
#>
function CreateMqConfigForZookeepper
{
    [CmdletBinding()]
    param(
        # ActiveMQ 配置信息
        [ActiveMQZookeeperConfig] $config
    )
    if ($null -eq $config)
    {
        Logger ERROR("ActiveMQ 配置信息不能为空")
        return;
    }

    # Logger DEBUG($config)
    

    CreateDir ( -Join ($config.BrokerPath, '\bin\win64') )
    CreateDir ( -Join ($config.BrokerPath, '\conf') )

    $srcWrapperConfigPath = Join-Path -Path $config.TemplatePath -ChildPath "bin\win64\wrapper.conf"
    $destWrapperConfigPath = Join-Path -Path $config.BrokerPath -ChildPath "bin\win64\wrapper.conf"

    (Get-Content $srcWrapperConfigPath) | ForEach-Object {
        $_ -replace '{{BrokerName}}', $config.BrokerName `
    } | Set-Content $destWrapperConfigPath


    $srcActiveMQConfigPath = Join-Path -Path $config.TemplatePath -ChildPath "conf\activemq.xml"
    $destActiveMQConfigPath = Join-Path -Path $config.BrokerPath -ChildPath "conf\activemq.xml"

    (Get-Content $srcActiveMQConfigPath -Encoding UTF8) | ForEach-Object {
        $_ -replace '{{BrokerName}}', $config.BrokerName `
            -replace '{{ClusterBrokerName}}', $config.ClusterBrokerName `
            -replace '{{BrokerPort}}', $config.BrokerPort `
            -replace '{{Replicas}}', $config.Replicas `
            -replace '{{BindPort}}', $config.BindPort `
            -replace '{{ZkAddress}}', $config.ZkAddress `
            -replace '{{ZkPassword}}', $config.ZkPassword `
            -replace '{{BrockerHostName}}', $config.BrockerHostName `
            -replace '{{Sync}}', $config.Sync `
            -replace '{{ZkPath}}', $config.ZkPath `
            -replace '{{NetworkConnectors}}', $config.NetworkConnectors `
            
    } | Set-Content $destActiveMQConfigPath -Encoding UTF8
 
    $srcJettyConfigPath = Join-Path -Path $config.TemplatePath -ChildPath "conf\jetty.xml"
    $destJettyConfigPath = Join-Path -Path $config.BrokerPath -ChildPath "conf\jetty.xml"

    (Get-Content $srcJettyConfigPath -Encoding UTF8) | ForEach-Object {
        $_ -replace '{{JettyPort}}', $config.JettyPort `
    } | Set-Content $destJettyConfigPath -Encoding UTF8

}

<#
    .DESCRIPTION
       复制 Zookeeper 的配置文件到指定目录

    .PARAMETER sourcePath
       来源目录

    .PARAMETER destPath
       目的地目录
        
    .EXAMPLE
      PS C:\> CopyMqConfig 
    
#>
function CopyZookeeperConfig
{
    [CmdletBinding()]
    param(
        # Zookeeper 来源目录
        [string]$sourcePath,
        # Zookeeper 目标目录
        [string]$destPath
    )
    If (([String]::IsNullOrEmpty($sourcePath)))
    {
        throw "目录地址不能为空"
    }
    if (!(Test-Path -Path $sourcePath))
    {
        throw "目录地址[`($sourcePath)`]不存在"
    } 
    # Zookeeper 启动配置文件
    # D:\Tools\Mq\ActiveMQ-Cluster\HA\apache-zookeeper-2183\conf\zoo.cfg
    $srcConfigPath = Join-Path -Path $sourcePath -ChildPath "conf\zoo.cfg"
    $destConfigDir = -Join ($destPath, '\conf')
    #Logger INFO("Zookeeper 启动配置文件, src:`"$srcConfigPath`",dest:`"$destConfigDir`" .")

    CopyOneItem -sourcePath $srcConfigPath -desFolder  $destConfigDir


    #  D:\Tools\Mq\ActiveMQ-Cluster\HA\apache-zookeeper-2181\data\myid
    # myid 配置文件
    $srcMyIdPath = Join-Path -Path $sourcePath  -ChildPath "data\myid"
    $destMyIdPath = -Join ($destPath, '\data')
    CopyOneItem -sourcePath $srcMyIdPath -desFolder  $destMyIdPath

}

<#
    .DESCRIPTION
        根据 Zookeeper 初始化 ActiveMQ 配置信息

    .PARAMETER clearData
        是否清除 data 数据
        
    .EXAMPLE
      PS C:\> IniteMqConfigs -clearData $false

     .EXAMPLE
      PS C:\> IniteMqConfigs -clearData $true
#>
function InitHAMqConfigsForZookeeper
{
    [CmdletBinding()]
    param(
        # 是否清除 ActiveMQ 目录下的 data 数据
        [Boolean] $clearData = $false
    )
    #$mqClusterSourcePath = "D:\Projects\Github\NoobWu\DistributeDocs\ActiveMQ\Cluster"
    $mqClusterSourcePath = "F:\Projects\NoobWu\DistributeDocs\ActiveMQ\Cluster"
    $mqClusterDestPath = "D:\Tools\MQ\ActiveMQ-Cluster"

    #region  集线 Broker（给生产者使用）
    $hubMQTemplatePath = -Join ( $mqClusterSourcePath, "\HA\apache-activemq-zookeeper-template")
    Logger INFO("开始，初始化集线 Broker`【$templatePath`】配置信息 ")
    $hubBrokerCount = 3;

    [ActiveMQZookeeperConfig[]]$hubMQConfigs = [ActiveMQZookeeperConfig[]]::new($hubBrokerCount)
    $hubBrokerUri = "static:(tcp://127.0.0.1:61612,tcp://127.0.0.1:61616,tcp://127.0.0.1:61617,tcp://127.0.0.1:61618)"
    $hubBrokerPort = 61611
    $hubJettyPort = 8161
    $hubReplicas = 1
    $hubBindPort = 61621
    $hubZkAddress = "127.0.0.1:2181,127.0.0.1:2182,127.0.0.1:2183"
    $hubBrockerHostName = "127.0.0.1"
    $hubZkPath = "/activemq/ha/leveldb-stores"
    for ($i = 0; $i -lt $hubBrokerCount; $i++)
    {
        $hubMQConfigs[$i] = [ActiveMQZookeeperConfig]::new()
        $hubMQConfigs[$i].ClusterBrokerName = "ActiveMQ-HA-Hub"
        $hubMQConfigs[$i].BrokerPort = $hubBrokerPort + $i
        $hubMQConfigs[$i].BrokerName = "ActiveMQ-HA-Hub-" + $hubMQConfigs[$i].BrokerPort
        $hubMQConfigs[$i].BrokerPath = -Join ($mqClusterSourcePath, "\HA\apache-activemq-hub-61611")
        $hubMQConfigs[$i].HubBrokerUri = $hubBrokerUri
        $hubMQConfigs[$i].JettyPort = $hubJettyPort + 1
        $hubMQConfigs[$i].TemplatePath = $hubMQTemplatePath
        $hubMQConfigs[$i].Replicas = $hubReplicas
        $hubMQConfigs[$i].BindPort = $hubBindPort + 1
        $hubMQConfigs[$i].ZkAddress = $hubZkAddress
        $hubMQConfigs[$i].ZkPassword = ""
        $hubMQConfigs[$i].BrockerHostName = $hubBrockerHostName
        $hubMQConfigs[$i].Sync = "local_disk"
        $hubMQConfigs[$i].ZkPath = $hubZkPath
    }

    foreach ($hubConfig in $hubMQConfigs)
    {
        # 根据模板创建配置信息
        CreateMqConfigForZookeepper $hubConfig 

        # 复制配置信息
        CopyMqConfig  -sourcePath $hubConfig.BrokerPath -destPath $hubConfig.BrokerPath.Replace($mqClusterSourcePath, $mqClusterDestPath)

        if ($clearData -eq $true)
        {
            #清除 data 数据
            ClearMqData -mqPath $hubConfig.BrokerPath.Replace($mqClusterSourcePath, $mqClusterDestPath)
        }
    }  
    Logger INFO("完成，初始化集线 Broker `【$templatePath`】配置信息 ")
    #endregion

    #region  消费Broker（给消费者使用）
    $templatePath = -Join ($mqClusterSourcePath, "\HA\apache-activemq-template")
    $brokerCount = 3;
    Logger INFO("开始，初始化`【$templatePath`】配置信息 ")
    [ActiveMQConfig[]]$mqConfigs = [ActiveMQConfig[]]::new($brokerCount)
    $brokerPort = 61616
    $jettyPort = 8166
    for ($i = 0; $i -lt $brokerCount; $i++)
    {
        $mqConfigs[$i] = [ActiveMQConfig]::new()
        $mqConfigs[$i].BrokerPort = ($brokerPort + $i)
        $mqConfigs[$i].BrokerName = "ActiveMQ-HA-" + $mqConfigs[$i].BrokerPort
        $mqConfigs[$i].BrokerPath = -Join ($mqClusterSourcePath, "\HA\apache-activemq-" + $mqConfigs[$i].BrokerPort)
        $mqConfigs[$i].HubBrokerUri = "masterslave:(tcp://127.0.0.1:61611,tcp://127.0.0.1:61612,tcp://127.0.0.1:61613)"
        $mqConfigs[$i].JettyPort = ($jettyPort + $i)
        $mqConfigs[$i].TemplatePath = $templatePath
    }

    #endregion

    foreach ($config in $mqConfigs)
    {
        # 根据模板创建配置信息
        CreateMqConfig $config 

        # 复制配置信息
        CopyMqConfig  -sourcePath $config.BrokerPath -destPath $config.BrokerPath.Replace($mqClusterSourcePath, $mqClusterDestPath)

        if ($clearData -eq $true)
        {
            #清除 data 数据
            ClearMqData -mqPath $config.BrokerPath.Replace($mqClusterSourcePath, $mqClusterDestPath)
        }
    }  

    Logger INFO("完成，初始化`【$templatePath`】配置信息 ")
   
}

# InitHAMqConfigsForZookeeper -clearData $true

<# 
    Zookeeper 配置信息
 #>
class ZookeeperConfig
{
    #  参数文档 https://github.com/HelloGitHub-Team/HelloZooKeeper/blob/main/content/6/content.md
    #当前节点的 myid yid 只要是不等于 -1 就行（-1 是一个固定的值会导致当前节点启动报错），不能大于 Long.MAX_VALUE 或者小于 Long.MIN_VALUE
    [int]$MyId
     
    #  Zookeeper模板所在目录
    [string]$TemplatePath

    #  Zookeeper 所在目录
    [string]$Path

    #  Zookeeper 所在目录
    [string]$DestPath

    # 监听client连接的端口号 2181
    [int]$ClientPort

    #是否启用后台管理
    [bool]$EnableServer

    #后台管理端口
    [int]$ServerPort

    #集群配置信息
    # server.X=A:B:C 其中 X 是一个数字, 表示这是第几号server. A是该server所在的IP地址. B配置该server和集群中的leader交换消息所使用的端口. C配置选举leader时所使用的端口. 
    # 由于配置的是伪集群模式, 所以各个server的B, C参数必须不同.
    #server.1=127.0.0.1:2888:3888
    #server.2=127.0.0.1:2889:3889
    #server.3=127.0.0.1:2890:3890
    [string]$ClusterServers

}

<#
    .DESCRIPTION
       根据模板文件创建 ZookeeperConfig 配置文件

    .PARAMETER config
        配置信息
        
    .EXAMPLE
     
    
      PS C:\> CreateZookeepperConfig $config
#>
function CreateZookeepperConfig
{
    [CmdletBinding()]
    param(
        # ActiveMQ 配置信息
        [ZookeeperConfig] $config
    )
    if ($null -eq $config)
    {
        Logger ERROR("Zookeepper 配置信息不能为空")
        return;
    }

    # Logger DEBUG($config)
    

    CreateDir ( -Join ($config.Path, '\conf') )
    CreateDir ( -Join ($config.Path, '\data') )

    $srcConfigPath = Join-Path -Path $config.TemplatePath -ChildPath "conf\zoo.cfg"
    $destConfigPath = Join-Path -Path $config.Path -ChildPath "conf\zoo.cfg"

    
    (Get-Content $srcConfigPath -Encoding UTF8) | ForEach-Object {
        $_ -replace '{{Path}}', $config.DestPath.Replace('\', '/') `
            -replace '{{ClientPort}}', $config.ClientPort `
            -replace '{{EnableServer}}', $config.EnableServer `
            -replace '{{ServerPort}}', $config.ServerPort `
            -replace '{{ClusterServers}}', $config.ClusterServers `
            
    } | Set-Content $destConfigPath -Encoding UTF8
 

    $srcMyIdPath = Join-Path -Path $config.TemplatePath -ChildPath "data\myid"
    $destMyIdPath = Join-Path -Path $config.Path -ChildPath "data\myid"
    $text = Get-Content -Raw $srcMyIdPath -Encoding UTF8
    $text = $text.Replace('{{MyId}}', $config.MyId)
    $utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
    [System.IO.File]::WriteAllLines($destMyIdPath, $text, $utf8NoBomEncoding)

    #(Get-Content $srcMyIdPath -encoding UTF8) | ForEach-Object {$_ -replace '{{MyId}}', $config.MyId} | Set-Content -NoNewline $destMyIdPath -encoding UTF8 $False

}


<#
    .DESCRIPTION
        根据 ActiveMQ 主从的 Zookeeper 配置信息

    .PARAMETER clearData
        是否清除 data 数据
        
    .EXAMPLE
      PS C:\> InitHAZookeepperConfigs -clearData $false

     .EXAMPLE
      PS C:\> InitHAZookeepperConfigs -clearData $true
#>
function InitHAZookeepperConfigs
{
    [CmdletBinding()]
    param(
        # 是否清除羽翼已有数据
        [Boolean] $clearData = $false
    )
   
    $count = 3;
    $mqClusterSourcePath = "F:\Projects\NoobWu\DistributeDocs\ActiveMQ\Cluster"
    $mqClusterDestPath = "D:\Tools\MQ\ActiveMQ-Cluster"
    $templatePath = -Join ($mqClusterSourcePath, "\HA\apache-zookeeper-template")

    Logger INFO("开始，初始化主从的 Zookeepper `【$templatePath`】配置信息 ")


    $clusterServers = -Join ("server.1=127.0.0.1:2881:3881", "`n", "server.2=127.0.0.1:2882:3882", "`n", "server.3=127.0.0.1:2883:3883", "`n")

    [ZookeeperConfig[]]$configs = [ZookeeperConfig[]]::new($count)
    $clientPort = 2181
    $serverPort = 8281
    $enableServer = $true
    $myId = 1
    for ($i = 0; $i -lt $count; $i++)
    {
        $configs[$i] = [ZookeeperConfig]::new()
        $configs[$i].TemplatePath = $templatePath
        $configs[$i].ClientPort = $clientPort + $i
        $configs[$i].Path = -Join ($mqClusterSourcePath, "\HA\apache-zookeeper-" + $configs[$i].ClientPort)
        $configs[$i].DestPath = -Join ($mqClusterDestPath, "\HA\apache-zookeeper-" + $configs[$i].ClientPort)
        $configs[$i].EnableServer = $enableServer
        $configs[$i].ServerPort = $serverPort + $i
        $configs[$i].ClusterServers = $clusterServers
        $configs[$i].MyId = $myId + $i
    }

    foreach ($config in $configs)
    {
        # 根据模板创建配置信息
        CreateZookeepperConfig $config 

        if ($clearData -eq $true)
        {
            $destDir = $config.Path.Replace($mqClusterSourcePath, $mqClusterDestPath)

            ClearDir -path ( -Join ($destDir, '\data')) 

            ClearDir -path ( -Join ($destDir, '\logs')) 

        } 

        # 复制配置信息
        CopyZookeeperConfig  -sourcePath $config.Path -destPath $config.Path.Replace($mqClusterSourcePath, $mqClusterDestPath)

    }  

    Logger INFO("完成，初始化主从的 Zookeepper `【$templatePath`】配置信息 ")

}

<#
    .DESCRIPTION
        根据 ActiveMQ 主从的 Zookeeper 配置信息

    .PARAMETER clearData
        是否清除 data 数据
        
    .EXAMPLE
      PS C:\> IniteMqConfigs -clearData $false

     .EXAMPLE
      PS C:\> IniteMqConfigs -clearData $true
#>
function InitMasterSlaveZookeepperConfigs
{
    [CmdletBinding()]
    param(
        # 是否清除羽翼已有数据
        [Boolean] $clearData = $false
    )
   
    $count = 3;
    $mqClusterSourcePath = "F:\Projects\NoobWu\DistributeDocs\ActiveMQ\Cluster"
    $mqClusterDestPath = "D:\Tools\MQ\ActiveMQ-Cluster"
    $templatePath = -Join ($mqClusterSourcePath, "\MS\apache-zookeeper-template")

    Logger INFO("开始，初始化主从的 Zookeepper `【$templatePath`】配置信息 ")


    $clusterServers = -Join ("server.1=127.0.0.1:2891:3891", "`n", "server.2=127.0.0.1:2892:3892", "`n", "server.3=127.0.0.1:2893:3893", "`n")

    [ZookeeperConfig[]]$configs = [ZookeeperConfig[]]::new($count)
    $clientPort = 2191
    $serverPort = 8291
    $enableServer = $true
    $myId = 1
    for ($i = 0; $i -lt $count; $i++)
    {
        $configs[$i] = [ZookeeperConfig]::new()
        $configs[$i].TemplatePath = $templatePath
        $configs[$i].ClientPort = $clientPort + $i
        $configs[$i].Path = -Join ($mqClusterSourcePath, "\MS\apache-zookeeper-" + $configs[$i].ClientPort)
        $configs[$i].DestPath = -Join ($mqClusterDestPath, "\MS\apache-zookeeper-" + $configs[$i].ClientPort)
        $configs[$i].EnableServer = $enableServer
        $configs[$i].ServerPort = $serverPort + $i
        $configs[$i].ClusterServers = $clusterServers
        $configs[$i].MyId = $myId + $i
    }

    foreach ($config in $configs)
    {
        # 根据模板创建配置信息
        CreateZookeepperConfig $config 

        if ($clearData -eq $true)
        {
            $destDir = $config.Path.Replace($mqClusterSourcePath, $mqClusterDestPath)

            ClearDir -path ( -Join ($destDir, '\data')) 

            ClearDir -path ( -Join ($destDir, '\logs')) 

        } 

        # 复制配置信息
        CopyZookeeperConfig  -sourcePath $config.Path -destPath $config.Path.Replace($mqClusterSourcePath, $mqClusterDestPath)

    }  

    Logger INFO("完成，初始化主从的 Zookeepper `【$templatePath`】配置信息 ")

}
 

<#
    .DESCRIPTION
        根据 Zookeeper 初始化 ActiveMQ 配置信息

    .PARAMETER clearData
        是否清除 data 数据
        
    .EXAMPLE
      PS C:\> InitMasterSlaveMQConfigs -clearData $false

     .EXAMPLE
      PS C:\> InitMasterSlaveMQConfigs -clearData $true
#>
function InitMasterSlaveMQConfigs
{
    [CmdletBinding()]
    param(
        # 是否清除 ActiveMQ 目录下的 data 数据
        [Boolean] $clearData = $false
    )
    #$mqClusterSourcePath = "D:\Projects\Github\NoobWu\DistributeDocs\ActiveMQ\Cluster"
    $mqClusterSourcePath = "F:\Projects\NoobWu\DistributeDocs\ActiveMQ\Cluster"
    $mqClusterDestPath = "D:\Tools\MQ\ActiveMQ-Cluster"

    $templatePath = -Join ( $mqClusterSourcePath, "\MS\apache-activemq-zookeeper-template")

    Logger INFO("开始，初始化主从MQ `【$templatePath`】配置信息 ")
    $brokerCount = 3;

    [ActiveMQZookeeperConfig[]]$mqConfigs = [ActiveMQZookeeperConfig[]]::new($brokerCount)
    $hubBrokerUri = "static:(tcp://127.0.0.1:61612,tcp://127.0.0.1:61616,tcp://127.0.0.1:61617,tcp://127.0.0.1:61618)"
    $brokerPort = 61816
    $jettyPort = 8186
    $replicas = 1
    $bindPort = 61826
    $zkAddress = "127.0.0.1:2191,127.0.0.1:2192,127.0.0.1:2193"
    $brockerHostName = "127.0.0.1"
    $zkPath = "/activemq/ms/leveldb-stores"
    $networkConnectors = ""
    for ($i = 0; $i -lt $brokerCount; $i++)
    {
        $mqConfigs[$i] = [ActiveMQZookeeperConfig]::new()
        $mqConfigs[$i].ClusterBrokerName = "ActiveMQ-MasterSlave"
        $mqConfigs[$i].BrokerPort = ($brokerPort + $i)
        $mqConfigs[$i].BrokerName = "ActiveMQ-MasterSlave-" + $mqConfigs[$i].BrokerPort
        $mqConfigs[$i].BrokerPath = -Join ($mqClusterSourcePath, "\MS\apache-activemq-" + $mqConfigs[$i].BrokerPort)
        $mqConfigs[$i].HubBrokerUri = $hubBrokerUri
        $mqConfigs[$i].JettyPort = ($jettyPort + 1)
        $mqConfigs[$i].TemplatePath = $templatePath
        $mqConfigs[$i].Replicas = $replicas
        $mqConfigs[$i].BindPort = ($bindPort + $i)
        $mqConfigs[$i].ZkAddress = $zkAddress
        $mqConfigs[$i].ZkPassword = ""
        $mqConfigs[$i].BrockerHostName = $brockerHostName
        $mqConfigs[$i].Sync = "local_disk"
        $mqConfigs[$i].ZkPath = $zkPath
        $mqConfigs[$i].NetworkConnectors = $networkConnectors
    }

  

    foreach ($config in $mqConfigs)
    {
        # 根据模板创建配置信息
        CreateMqConfigForZookeepper $config 

        # 复制配置信息
        CopyMqConfig  -sourcePath $config.BrokerPath -destPath $config.BrokerPath.Replace($mqClusterSourcePath, $mqClusterDestPath)

        if ($clearData -eq $true)
        {
            #清除 data 数据
            ClearMqData -mqPath $config.BrokerPath.Replace($mqClusterSourcePath, $mqClusterDestPath)
        }
    }  

    Logger INFO("完成，初始化主从MQ `【$templatePath`】配置信息 ")

   
}

#初始化 Zookeepper 配置信息
#InitMasterSlaveZookeepperConfigs  -clearData $true

#初始化 MQ 配置信息
#InitMasterSlaveMQConfigs -clearData $true

#初始化负载均衡 MQ 配置信息
InitLoadBalanceMqConfigs  -clearData $true