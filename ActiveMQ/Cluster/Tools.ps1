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

    .PARAMETER Level
        日志类型(VERBOSE,DEBUG, INFO, WARNING, ERROR)

    .PARAMETER Message
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
       清空ActiveMQ目录下的data目录的内容

    .PARAMETER Level
        日志类型(VERBOSE,DEBUG, INFO, WARNING, ERROR)
        
    .EXAMPLE
        PS C:\> ClearMqData @("D:\Tools\MQ\ActiveMQ-Cluster\LB\apache-activemq-61716")

#>
function ClearMqData {
    [CmdletBinding()]
    param(
        #ActiveMQ所在目录数组
        [string[]] $mqPaths
    )

    foreach ($mqPath in $mqPaths) {
        # Log -Level DEBUG -Message "path: $mqPath"
    
        #删除data目录中的子文件夹
        $dataPath = Join-Path -Path $mqPath -ChildPath "\data"
        #$dataPath=-Join ($mqPath, '\data')
    
        # Remove-Item $dataPath -Recurse -Force
        #Log WARNING("删除目录 `"$dataPath`".")
    
        #清空data目录中的文件夹及文件
        Get-ChildItem -Path $dataPath -Recurse -Force | Remove-Item -Recurse -Force
        Log WARNING("清空目录 `"$dataPath`"  中的文件夹及文件.")
    
    }
    
}


<# # 清空ActiveMQ目录下的data目录的内容
$mqClusterPath = 'D:\Tools\MQ\ActiveMQ-Cluster'
$mqPaths = @( -Join ($mqClusterPath, '\LB\apache-activemq-hub-61711'), -Join ($mqClusterPath, '\LB\apache-activemq-hub-61712'), -Join ($mqClusterPath, '\LB\apache-activemq-61716'), -Join ($mqClusterPath, '\LB\apache-activemq-61717'), -Join ($mqClusterPath, '\LB\apache-activemq-61718'))
ClearMqData -mqPaths $mqPaths #>



