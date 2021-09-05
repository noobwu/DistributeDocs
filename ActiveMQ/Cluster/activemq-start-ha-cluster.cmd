@echo off
echo Starting ActiveMQ HA Cluster : 61616-61618
rem pushd %~dp0
pushd "D:\Tools\MQ\ActiveMQ-Cluster"  rem 指定目录
@start "ActiveMQ (HA Cluster Hub): 61611" /min HA\apache-activemq-hub-61611\bin\win64\activemq.bat
@start "ActiveMQ (HA Cluster Hub): 61612" /min HA\apache-activemq-hub-61612\bin\win64\activemq.bat
@start "ActiveMQ (HA Cluster Hub): 61613" /min HA\apache-activemq-hub-61613\bin\win64\activemq.bat
@start "ActiveMQ (HA Cluster): 61616" /min HA\apache-activemq-61616\bin\win64\activemq.bat
@start "ActiveMQ (HA Cluster): 61617" /min HA\apache-activemq-61617\bin\win64\activemq.bat
@start "ActiveMQ (HA Cluster): 61618" /min HA\apache-activemq-61618\bin\win64\activemq.bat
popd
rem pause
