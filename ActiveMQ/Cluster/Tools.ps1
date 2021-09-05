<#
    .SYNOPSIS
       Replace Token

    .DESCRIPTION
        设置日志
#>
function SetLoggergingVariables {

    #Already setup
    if ($Script:Loggerging -and $Script:LevelNames) {
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
    if ($null -eq $ScriptRoot) {
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
function ReplaceToken {
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
    foreach ($match in $tokenMatches) {
        $formattedEntry = [string]::Empty
        $tokenContent = [string]::Empty

        $token = $match.Groups["token"].value
        $datefmt = $match.Groups["datefmt"].value
        $datefmtU = $match.Groups["datefmtU"].value
        $padding = $match.Groups["padding"].value

        [hashtable] $dateParam = @{ }
        if (-not [string]::IsNullOrWhiteSpace($token)) {
            $tokenContent = $Source.$token
            $dateParam["Date"] = $tokenContent
        }

        if (-not [string]::IsNullOrWhiteSpace($datefmtU)) {
            $formattedEntry = Get-Date @dateParam -UFormat $datefmtU
        }
        elseif (-not [string]::IsNullOrWhiteSpace($datefmt)) {
            $formattedEntry = Get-Date @dateParam -Format $datefmt
        }
        else {
            $formattedEntry = $tokenContent
        }

        if ($padding) {
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
function Logger {
    [CmdletBinding()]
    param(
        #日志级别
        [ValidateSet("VERBOSE", "DEBUG", "INFO", "WARNING", "ERROR")]
        [string] $level,
        #日志信息
        [string] $message
    )
    if ($null -ne $level) {
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
    if ($colorMapping.ContainsKey($level)) {
        $Host.UI.WriteLine($colorMapping[$level], $Host.UI.RawUI.BackgroundColor, $logText)
    }
    else {
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
function CreateDir {
    [CmdletBinding()]
    param(
        [string] $dirPath
    )
    
    # Logger DEBUG("dirPath:`"$dirPath`"")

    if ((Test-Path -Path $dirPath)) {
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
function CopyFolder {
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
      

    if (!(Test-Path -Path $sourcePath)) {
        log WARNING("CopyFolder  Folder   `"$sourcePath`" no exists.")
        return			
    }
    if (!(Test-Path -Path $desFolder)) {
        New-Item $desFolder -Type Directory
        if (!(Test-Path -Path $desFolder)) {
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
function CopyOneItem {
    param
    (
        #源文件或者文件夹地址
        [string] 
        $sourcePath,
        #目标文件或者文件夹地址
        [string] 
        $desFolder
    )
    if (!(Test-Path -Path $sourcePath)) {
        Logger WARNING("CopyOneItem  file   `"$sourcePath`" no exists.")
        return			
    }
    if (!(Test-Path -Path $desFolder)) {
        New-Item $desFolder -Type Directory
        if (!(Test-Path -Path $desFolder)) {
            return
        }
    }
    # Logger  DEBUG("Copy directory from `"$sourcePath`"  start.")	

    if ($sourcePath -is [System.IO.DirectoryInfo]) {
        CopyFolder -sourcePath $sourcePath -desFolder $desFolder
    }
    else {
        Copy-Item -Path $sourcePath -Destination $desFolder -Force
        # Logger INFO("Copy file from  `"$sourcePath`" to `"$desFolder`" successfully.")			 
    }
}
 

<#
    .DESCRIPTION
       清空 ActiveMQ 目录下的 data 目录的内容

    .PARAMETER Level
        日志类型(VERBOSE,DEBUG, INFO, WARNING, ERROR)
        
    .EXAMPLE
      PS C:\> ClearMqData @("D:\Tools\MQ\ActiveMQ-Cluster\LB\apache-activemq-61716")
    
    .EXAMPLE
      # 清空ActiveMQ目录下的data目录的内容
      $mqClusterPath = 'D:\Tools\MQ\ActiveMQ-Cluster'
      $mqPaths = @( -Join ($mqClusterPath, '\LB\apache-activemq-hub-61711'), -Join ($mqClusterPath, '\LB\apache-activemq-hub-61712'), -Join ($mqClusterPath, '\LB\apache-activemq-61716'), -Join ($mqClusterPath, '\LB\apache-activemq-61717'), -Join ($mqClusterPath, '\LB\apache-activemq-61718'))
      PS C:\> ClearMqData $mqPaths

#>
function ClearMqData {
    [CmdletBinding()]
    param(
        # ActiveMQ 所在目录
        [string[]] $mqPath
    )
    If (([String]::IsNullOrEmpty($mqPath))) {
        throw "路径不能为空"
    }
    if (!(Test-Path -Path $mqPath)) {
        throw "路径地址[`($mqPath)`]不存在"
    } 

    $dataPath = Join-Path -Path $mqPath -ChildPath "\data"
    #$dataPath=-Join ($mqPath, '\data')

    #删除data文件夹
    # Remove-Item $dataPath -Recurse -Force
    #Logger WARNING("删除文件夹 `"$dataPath`".")
    
    #清空data下的文件夹及文件
    Get-ChildItem -Path $dataPath -Recurse -Force | Remove-Item -Recurse -Force
    # Logger WARNING("清空 `"$dataPath`"  中的文件夹及文件.")
    
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
function CopyMqConfig {
    [CmdletBinding()]
    param(
        # ActiveMQ 来源目录
        [string]$sourcePath,
        # ActiveMQ 目标目录
        [string]$destPath
    )
    If (([String]::IsNullOrEmpty($sourcePath))) {
        throw "目录地址不能为空"
    }
    if (!(Test-Path -Path $sourcePath)) {
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
class ActiveMQConfig {
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

    # Broker管理后台端口 8176
    [int]$JettyPort

    [string]ToString() {
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
function CreateMqConfig {
    [CmdletBinding()]
    param(
        # ActiveMQ 配置信息
        [ActiveMQConfig] $config
    )
    if ($null -eq $config) {
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
            -replace '{{BrokerPort}}', $config.BrokerPort `
            -replace '{{HubBrokerUri}}', $config.HubBrokerUri `
            -replace '{{JettyPort}}', $config.JettyPort `
    } | Set-Content $destWrapperConfigPath


    $srcActiveMQConfigPath = Join-Path -Path $config.TemplatePath -ChildPath "conf\activemq.xml"
    $destActiveMQConfigPath = Join-Path -Path $config.BrokerPath -ChildPath "conf\activemq.xml"

    (Get-Content $srcActiveMQConfigPath) | ForEach-Object {
        $_ -replace '{{BrokerName}}', $config.BrokerName `
            -replace '{{BrokerPort}}', $config.BrokerPort `
            -replace '{{HubBrokerUri}}', $config.HubBrokerUri `
            -replace '{{JettyPort}}', $config.JettyPort `
    } | Set-Content $destActiveMQConfigPath
 
    $srcJettyConfigPath = Join-Path -Path $config.TemplatePath -ChildPath "conf\jetty.xml"
    $destJettyConfigPath = Join-Path -Path $config.BrokerPath -ChildPath "conf\jetty.xml"

    (Get-Content $srcJettyConfigPath) | ForEach-Object {
        $_ -replace '{{BrokerName}}', $config.BrokerName `
            -replace '{{BrokerPort}}', $config.BrokerPort `
            -replace '{{HubBrokerUri}}', $config.HubBrokerUri `
            -replace '{{JettyPort}}', $config.JettyPort `
    } | Set-Content $destJettyConfigPath

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
function IniteMqConfigs {
    [CmdletBinding()]
    param(
        # ActiveMQ 配置信息
        [Boolean] $clearData = $false
    )
    $mqClusterSourcePath = "D:\Projects\Github\NoobWu\DistributeDocs\ActiveMQ\Cluster"
    $mqClusterDestPath = "D:\Tools\MQ\ActiveMQ-Cluster"
    $templatePath = "D:\Projects\Github\NoobWu\DistributeDocs\ActiveMQ\Cluster\LB\apache-activemq-template"
    $brokerCount = 5;

    Logger INFO("开始，初始化`【$templatePath`】配置信息 ")

    [ActiveMQConfig[]]$mqConfigs = [ActiveMQConfig[]]::new($brokerCount)

    #region  集线 Broker（给生产者使用）
    $mqConfigs[0] = [ActiveMQConfig]::new()
    $mqConfigs[0].BrokerName = "ActiveMQ-LB-Hub-61711"
    $mqConfigs[0].BrokerPort = 61711
    $mqConfigs[0].BrokerPath = -Join ($mqClusterSourcePath, "\LB\apache-activemq-hub-61711")
    $mqConfigs[0].HubBrokerUri = "static:(tcp://127.0.0.1:61712,tcp://127.0.0.1:61716,tcp://127.0.0.1:61717,tcp://127.0.0.1:61718)"
    $mqConfigs[0].JettyPort = 8171
    $mqConfigs[0].TemplatePath = $templatePath

    $mqConfigs[1] = [ActiveMQConfig]::new()
    $mqConfigs[1].BrokerName = "ActiveMQ-LB-Hub-61712"
    $mqConfigs[1].BrokerPort = 61712
    $mqConfigs[1].BrokerPath = -Join ($mqClusterSourcePath, "\LB\apache-activemq-hub-61712")
    $mqConfigs[1].HubBrokerUri = "static:(tcp://127.0.0.1:61711,tcp://127.0.0.1:61716,tcp://127.0.0.1:61717,tcp://127.0.0.1:61718)"
    $mqConfigs[1].JettyPort = 8172
    $mqConfigs[1].TemplatePath = $templatePath
    #endregion 集线 Broker（给生产者使用）
	

    #region  消费Broker（给消费者使用）
    $mqConfigs[2] = [ActiveMQConfig]::new()
    $mqConfigs[2].BrokerName = "ActiveMQ-LB-61716"
    $mqConfigs[2].BrokerPort = 61716
    $mqConfigs[2].BrokerPath = -Join ($mqClusterSourcePath, "\LB\apache-activemq-61716")
    $mqConfigs[2].HubBrokerUri = "static:(tcp://127.0.0.1:61711,tcp://127.0.0.1:61712)"
    $mqConfigs[2].JettyPort = 8176
    $mqConfigs[2].TemplatePath = $templatePath

    $mqConfigs[3] = [ActiveMQConfig]::new()
    $mqConfigs[3].BrokerName = "ActiveMQ-LB-61717"
    $mqConfigs[3].BrokerPort = 61717
    $mqConfigs[3].BrokerPath = -Join ($mqClusterSourcePath, "\LB\apache-activemq-61717")
    $mqConfigs[3].HubBrokerUri = "static:(tcp://127.0.0.1:61711,tcp://127.0.0.1:61712)"
    $mqConfigs[3].JettyPort = 8177
    $mqConfigs[3].TemplatePath = $templatePath

    $mqConfigs[4] = [ActiveMQConfig]::new()
    $mqConfigs[4].BrokerName = "ActiveMQ-LB-61718"
    $mqConfigs[4].BrokerPort = 61718
    $mqConfigs[4].BrokerPath = -Join ($mqClusterSourcePath, "\LB\apache-activemq-61718")
    $mqConfigs[4].HubBrokerUri = "static:(tcp://127.0.0.1:61711,tcp://127.0.0.1:61712)"
    $mqConfigs[4].JettyPort = 8178
    $mqConfigs[4].TemplatePath = $templatePath

    #endregion

    foreach ($config in $mqConfigs) {
        # 根据模板创建配置信息
        CreateMqConfig $config 

        # 复制配置信息
        CopyMqConfig  -sourcePath $config.BrokerPath -destPath $config.BrokerPath.Replace($mqClusterSourcePath, $mqClusterDestPath)

        if ($clearData -eq $true) {
            #清除 data 数据
            ClearMqData -mqPath $config.BrokerPath.Replace($mqClusterSourcePath, $mqClusterDestPath)
        }
    }  

    Logger INFO("完成，初始化`【$templatePath`】配置信息 ")
   
}

#IniteMqConfigs -clearData $true


<# 
    ActiveMQ  配置信息(Zookeeper配置主)
 #>
class ZookeeperConfig:ActiveMQConfig {
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
function CreateMqConfigForZookeepper {
    [CmdletBinding()]
    param(
        # ActiveMQ 配置信息
        [ZookeeperConfig] $config
    )
    if ($null -eq $config) {
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

    (Get-Content $srcActiveMQConfigPath) | ForEach-Object {
        $_ -replace '{{BrokerName}}', $config.BrokerName `
            -replace '{{ClusterBrokerName}}', $config.ClusterBrokerName `
            -replace '{{BrokerPort}}', $config.BrokerPort `
            -replace '{{HubBrokerUri}}', $config.HubBrokerUri `
            -replace '{{Replicas}}', $config.Replicas `
            -replace '{{BindPort}}', $config.BindPort `
            -replace '{{ZkAddress}}', $config.ZkAddress `
            -replace '{{ZkPassword}}', $config.ZkPassword `
            -replace '{{BrockerHostName}}', $config.BrockerHostName `
            -replace '{{Sync}}', $config.Sync `
            -replace '{{ZkPath}}', $config.ZkPath `
            
    } | Set-Content $destActiveMQConfigPath
 
    $srcJettyConfigPath = Join-Path -Path $config.TemplatePath -ChildPath "conf\jetty.xml"
    $destJettyConfigPath = Join-Path -Path $config.BrokerPath -ChildPath "conf\jetty.xml"

    (Get-Content $srcJettyConfigPath) | ForEach-Object {
        $_ -replace '{{JettyPort}}', $config.JettyPort `
    } | Set-Content $destJettyConfigPath

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
function IniteMqConfigsForZookeeper {
    [CmdletBinding()]
    param(
        # ActiveMQ 配置信息
        [Boolean] $clearData = $false
    )
    $mqClusterSourcePath = "D:\Projects\Github\NoobWu\DistributeDocs\ActiveMQ\Cluster"
    $mqClusterDestPath = "D:\Tools\MQ\ActiveMQ-Cluster"


    Logger INFO("开始，初始化`【$templatePath`】配置信息 ")

    #region  集线 Broker（给生产者使用）
    $hubMQTemplatePath = "D:\Projects\Github\NoobWu\DistributeDocs\ActiveMQ\Cluster\HA\apache-activemq-zookeeper-template"
    $hubBrokerCount = 3;

    [ZookeeperConfig[]]$hubMQConfigs = [ZookeeperConfig[]]::new($hubBrokerCount)

    $hubMQConfigs[0] = [ZookeeperConfig]::new()
    $hubMQConfigs[0].ClusterBrokerName = "ActiveMQ-HA-Hub"
    $hubMQConfigs[0].BrokerName = "ActiveMQ-HA-Hub-61611"
    $hubMQConfigs[0].BrokerPort = 61611
    $hubMQConfigs[0].BrokerPath = -Join ($mqClusterSourcePath, "\HA\apache-activemq-hub-61611")
    $hubMQConfigs[0].HubBrokerUri = "static:(tcp://127.0.0.1:61616,tcp://127.0.0.1:61617,tcp://127.0.0.1:61618)"
    $hubMQConfigs[0].JettyPort = 8161
    $hubMQConfigs[0].TemplatePath = $hubMQTemplatePath
    $hubMQConfigs[0].Replicas = 1
    $hubMQConfigs[0].BindPort = 61621
    $hubMQConfigs[0].ZkAddress = "127.0.0.1:2181,127.0.0.1:2182,127.0.0.1:2183"
    $hubMQConfigs[0].ZkPassword = ""
    $hubMQConfigs[0].BrockerHostName = "127.0.0.1"
    $hubMQConfigs[0].Sync = "local_disk"
    $hubMQConfigs[0].ZkPath = "/activemq/ha/leveldb-stores"

    $hubMQConfigs[1] = [ZookeeperConfig]::new()
    $hubMQConfigs[1].ClusterBrokerName = "ActiveMQ-HA-Hub"
    $hubMQConfigs[1].BrokerName = "ActiveMQ-HA-Hub-61612"
    $hubMQConfigs[1].BrokerPort = 61612
    $hubMQConfigs[1].BrokerPath = -Join ($mqClusterSourcePath, "\HA\apache-activemq-hub-61612")
    $hubMQConfigs[1].HubBrokerUri = "static:(tcp://127.0.0.1:61616,tcp://127.0.0.1:61617,tcp://127.0.0.1:61618)"
    $hubMQConfigs[1].JettyPort = 8162
    $hubMQConfigs[1].TemplatePath = $hubMQTemplatePath
    $hubMQConfigs[1].Replicas = 1
    $hubMQConfigs[1].BindPort = 61622
    $hubMQConfigs[1].ZkAddress = "127.0.0.1:2181,127.0.0.1:2182,127.0.0.1:2183"
    $hubMQConfigs[1].ZkPassword = ""
    $hubMQConfigs[1].BrockerHostName = "127.0.0.1"
    $hubMQConfigs[1].Sync = "local_disk"
    $hubMQConfigs[1].ZkPath = "/activemq/ha/leveldb-stores"

    $hubMQConfigs[2] = [ZookeeperConfig]::new()
    $hubMQConfigs[2].ClusterBrokerName = "ActiveMQ-HA-Hub"
    $hubMQConfigs[2].BrokerName = "ActiveMQ-HA-Hub-61613"
    $hubMQConfigs[2].BrokerPort = 61613
    $hubMQConfigs[2].BrokerPath = -Join ($mqClusterSourcePath, "\HA\apache-activemq-hub-61613")
    $hubMQConfigs[2].HubBrokerUri = "static:(tcp://127.0.0.1:61616,tcp://127.0.0.1:61617,tcp://127.0.0.1:61618)"
    $hubMQConfigs[2].JettyPort = 8163
    $hubMQConfigs[2].TemplatePath = $hubMQTemplatePath
    $hubMQConfigs[2].Replicas = 1
    $hubMQConfigs[2].BindPort = 61623
    $hubMQConfigs[2].ZkAddress = "127.0.0.1:2181,127.0.0.1:2182,127.0.0.1:2183"
    $hubMQConfigs[2].ZkPassword = ""
    $hubMQConfigs[2].BrockerHostName = "127.0.0.1"
    $hubMQConfigs[2].Sync = "local_disk"
    $hubMQConfigs[2].ZkPath = "/activemq/ha/leveldb-stores"

    foreach ($hubConfig in $hubMQConfigs) {
        # 根据模板创建配置信息
        CreateMqConfigForZookeepper $hubConfig 

        # 复制配置信息
        CopyMqConfig  -sourcePath $hubConfig.BrokerPath -destPath $hubConfig.BrokerPath.Replace($mqClusterSourcePath, $mqClusterDestPath)

        if ($clearData -eq $true) {
            #清除 data 数据
            ClearMqData -mqPath $hubConfig.BrokerPath.Replace($mqClusterSourcePath, $mqClusterDestPath)
        }
    }  

    #endregion

    #region  消费Broker（给消费者使用）
    $templatePath = "D:\Projects\Github\NoobWu\DistributeDocs\ActiveMQ\Cluster\HA\apache-activemq-template"
    $brokerCount = 3;
    [ActiveMQConfig[]]$mqConfigs = [ActiveMQConfig[]]::new($brokerCount)
    $mqConfigs[0] = [ActiveMQConfig]::new()
    $mqConfigs[0].BrokerName = "ActiveMQ-HA-61616"
    $mqConfigs[0].BrokerPort = 61616
    $mqConfigs[0].BrokerPath = -Join ($mqClusterSourcePath, "\HA\apache-activemq-61616")
    $mqConfigs[0].HubBrokerUri = "static:(tcp://127.0.0.1:61611,tcp://127.0.0.1:61612,tcp://127.0.0.1:61613)"
    $mqConfigs[0].JettyPort = 8166
    $mqConfigs[0].TemplatePath = $templatePath

    $mqConfigs[1] = [ActiveMQConfig]::new()
    $mqConfigs[1].BrokerName = "ActiveMQ-HA-61617"
    $mqConfigs[1].BrokerPort = 61617
    $mqConfigs[1].BrokerPath = -Join ($mqClusterSourcePath, "\HA\apache-activemq-61617")
    $mqConfigs[1].HubBrokerUri = "static:(tcp://127.0.0.1:61611,tcp://127.0.0.1:61612,tcp://127.0.0.1:61613)"
    $mqConfigs[1].JettyPort = 8167
    $mqConfigs[1].TemplatePath = $templatePath

    $mqConfigs[2] = [ActiveMQConfig]::new()
    $mqConfigs[2].BrokerName = "ActiveMQ-HA-61618"
    $mqConfigs[2].BrokerPort = 61618
    $mqConfigs[2].BrokerPath = -Join ($mqClusterSourcePath, "\HA\apache-activemq-61618")
    $mqConfigs[2].HubBrokerUri = "static:(tcp://127.0.0.1:61611,tcp://127.0.0.1:61612,tcp://127.0.0.1:61613)"
    $mqConfigs[2].JettyPort = 8168
    $mqConfigs[2].TemplatePath = $templatePath

    #endregion

    foreach ($config in $mqConfigs) {
        # 根据模板创建配置信息
        CreateMqConfig $config 

        # 复制配置信息
        CopyMqConfig  -sourcePath $config.BrokerPath -destPath $config.BrokerPath.Replace($mqClusterSourcePath, $mqClusterDestPath)

        if ($clearData -eq $true) {
            #清除 data 数据
            ClearMqData -mqPath $config.BrokerPath.Replace($mqClusterSourcePath, $mqClusterDestPath)
        }
    }  

    Logger INFO("完成，初始化`【$templatePath`】配置信息 ")
   
}

IniteMqConfigsForZookeeper -clearData $true