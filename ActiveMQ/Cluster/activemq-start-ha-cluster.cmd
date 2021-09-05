@echo off
echo Starting ActiveMQ HA Cluster : 61616-61618
rem pushd %~dp0
@start "ActiveMQ (HA Cluster Hub): 61616" /min HA\apache-activemq-hub-61616\bin\win64\activemq.bat
@start "ActiveMQ (HA Cluster Hub): 61617" /min HA\apache-activemq-hub-61617\bin\win64\activemq.bat
@start "ActiveMQ (HA Cluster Hub): 61618" /min HA\apache-activemq-hub-61618\bin\win64\activemq.bat
@start "ActiveMQ (HA Cluster): 61611" /min HA\apache-activemq-61611\bin\win64\activemq.bat
@start "ActiveMQ (HA Cluster): 61612" /min HA\apache-activemq-61612\bin\win64\activemq.bat
@start "ActiveMQ (HA Cluster): 61613" /min HA\apache-activemq-61613\bin\win64\activemq.bat
popd
