$LogColor = @{
    VERBOSE = "gray";
    DEBUG   = "white";
    INFO    = "green";
    WARNING = "yellow";
    ERROR   = "red";
}
<#
    .DESCRIPTION
       控制台输出日志

    .PARAMETER level
        日志类型(VERBOSE,DEBUG, INFO, WARNING, ERROR)

    .PARAMETER message
        日志内容

    .EXAMPLE
        PS C:\> Log -Level ERROR -Message 'Hello, World!'

#>
function Log {
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
    $date = Get-Date -UFormat "%G-%m-%d %T"
    Write-Host "[$date] " -NoNewline
    Write-Host -ForegroundColor $LogColor[$level] $level.padright(7)  -NoNewline
    Write-Host -ForegroundColor $LogColor[$level] " $message"
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
    log INFO("复制`"$sourcePath`" 下的所有文件及子文件夹到 `"$desFolder`" 开始...")	

    Copy-Item -Path $sourcePath -Destination $desFolder -Recurse  -Force

    log INFO("复制`"$sourcePath`" 下的所有文件及子文件夹到 `"$desFolder`" 结束.")	

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
        log WARNING("CopyOneItem  file   `"$sourcePath`" no exists.")
        return			
    }
    if (!(Test-Path -Path $desFolder)) {
        New-Item $desFolder -Type Directory
        if (!(Test-Path -Path $desFolder)) {
            return
        }
    }
    Log  DEBUG("Copy directory from `"$sourcePath`"  start.")	

    if ($sourcePath -is [System.IO.DirectoryInfo]) {
        CopyFolder -sourcePath $sourcePath -desFolder $desFolder
    }
    else {
        Copy-Item -Path $sourcePath -Destination $desFolder -Force
        log INFO("Copy file from  `"$sourcePath`" to `"$desFolder`" successfully.")			 
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
        # ActiveMQ 所在目录数组
        [string[]] $mqPaths
    )

    foreach ($mqPath in $mqPaths) {
        $dataPath = Join-Path -Path $mqPath -ChildPath "\data"
        #$dataPath=-Join ($mqPath, '\data')

        #删除data目录中的子文件夹
        # Remove-Item $dataPath -Recurse -Force
        #Log WARNING("删除目录 `"$dataPath`".")
    
        #清空data目录中的文件夹及文件
        Get-ChildItem -Path $dataPath -Recurse -Force | Remove-Item -Recurse -Force
        Log WARNING("清空目录 `"$dataPath`"  中的文件夹及文件.")
    }
    
}


<#
    .DESCRIPTION
       复制 ActiveMQ 目录下的配置文件

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
function CopyMqConfigs {
    [CmdletBinding()]
    param(
        # ActiveMQ 集群配置信息
        [ClusterConfig[]] $clusterConfigs
    )
    foreach ($config in $clusterConfigs) {
        # ActiveMQ 启动配置文件
        # D:\Tools\MQ\ActiveMQ-Cluster\LB\apache-activemq-hub-61711\bin\win64\wrapper.conf
        $srcWrapperConfigPath = Join-Path -Path $config.SourcePath -ChildPath "bin\win64\wrapper.conf"
        $destWrapperConfigDir = -Join ($config.DestPath, '\bin\win64')
        #Log INFO("ActiveMQ 启动配置文件, src:`"$srcWrapperConfigPath`",dest:`"$destWrapperConfigDir`" .")

        CopyOneItem -sourcePath $srcWrapperConfigPath -desFolder  $destWrapperConfigDir


        #  D:\Tools\MQ\ActiveMQ-Cluster\LB\apache-activemq-hub-61711\conf\activemq.xml
        # ActiveMQ 配置文件
        $srcActiveMqConfigPath = Join-Path -Path $config.SourcePath -ChildPath "conf\activemq.xml"
        $destActiveMqConfigDir = -Join ($config.DestPath, '\conf')
        CopyOneItem -sourcePath $srcActiveMqConfigPath -desFolder  $destActiveMqConfigDir


        # D:\Tools\MQ\ActiveMQ-Cluster\LB\apache-activemq-hub-61711\conf\jetty.xml
        # ActiveMQ 后台管理配置文件
        $srcJettyConfigPath = Join-Path -Path $config.SourcePath -ChildPath "conf\jetty.xml"
        $destJettyConfigDir =   -Join ($config.DestPath, '\conf')
        CopyOneItem -sourcePath $srcJettyConfigPath -desFolder  $destJettyConfigDir

    }
    
}

class ClusterConfig {
    # 源文件夹
    [string]$SourcePath

    # 目标文件夹
    [string]$DestPath

    [string]ToString() {
        return ("{0}|{1}" -f $this.SourcePath, $this.TargetPath)
    }
}
$mqClusterSourcePath = 'D:\Tools\MQ\ActiveMQ-Cluster'
$mqClusterDestPath = 'D:\Projects\Github\NoobWu\DistributeDocs\ActiveMQ\Cluster'

[ClusterConfig[]]$clusterConfigs = [ClusterConfig[]]::new(5)
$clusterConfigs[0] = [ClusterConfig]::new()
$clusterConfigs[0].SourcePath = -Join ($mqClusterSourcePath, '\LB\apache-activemq-hub-61711')
$clusterConfigs[0].DestPath = -Join ($mqClusterDestPath, '\LB\apache-activemq-hub-61711')

$clusterConfigs[1] = [ClusterConfig]::new()
$clusterConfigs[1].SourcePath = -Join ($mqClusterSourcePath, '\LB\apache-activemq-hub-61712')
$clusterConfigs[1].DestPath = -Join ($mqClusterDestPath, '\LB\apache-activemq-hub-61712')

$clusterConfigs[2] = [ClusterConfig]::new()
$clusterConfigs[2].SourcePath = -Join ($mqClusterSourcePath, '\LB\apache-activemq-61716')
$clusterConfigs[2].DestPath = -Join ($mqClusterDestPath, '\LB\apache-activemq-61716')

$clusterConfigs[3] = [ClusterConfig]::new()
$clusterConfigs[3].SourcePath = -Join ($mqClusterSourcePath, '\LB\apache-activemq-61717')
$clusterConfigs[3].DestPath = -Join ($mqClusterDestPath, '\LB\apache-activemq-61717')

$clusterConfigs[4] = [ClusterConfig]::new()
$clusterConfigs[4].SourcePath = -Join ($mqClusterSourcePath, '\LB\apache-activemq-61718')
$clusterConfigs[4].DestPath = -Join ($mqClusterDestPath, '\LB\apache-activemq-61718') 


CopyMqConfigs $clusterConfigs