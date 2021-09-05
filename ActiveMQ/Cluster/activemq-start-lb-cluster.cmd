@echo off
echo Starting ActiveMQ LB Cluster : 61716-61718
rem pushd %~dp0 rem 当前目录
pushd "D:\Tools\MQ\ActiveMQ-Cluster"  rem 指定目录
@start "ActiveMQ (LB Cluster): 61711" /min LB\apache-activemq-hub-61711\bin\win64\activemq.bat
@start "ActiveMQ (LB Cluster): 61712" /min LB\apache-activemq-hub-61712\bin\win64\activemq.bat
@start "ActiveMQ (LB Cluster): 61716" /min LB\apache-activemq-61716\bin\win64\activemq.bat
@start "ActiveMQ (LB Cluster): 61717" /min LB\apache-activemq-61717\bin\win64\activemq.bat
@start "ActiveMQ (LB Cluster): 61718" /min LB\apache-activemq-61718\bin\win64\activemq.bat
popd
