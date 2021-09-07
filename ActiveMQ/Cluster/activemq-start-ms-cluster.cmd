@echo off
echo Starting Zookeeper Cluster: 2191-2193
pushd %~dp0
@start "Zookeeper (Cluster): 2191" /min MS\apache-zookeeper-2191\bin\zkServer.cmd
@start "Zookeeper (Cluster): 2192" /min MS\apache-zookeeper-2192\bin\zkServer.cmd
@start "Zookeeper (Cluster): 2193" /min MS\apache-zookeeper-2193\bin\zkServer.cmd
popd

timeout /t 10 /nobreak > NUL

rem ping 127.0.0.1 >nul

@echo off
echo Starting ActiveMQ MS Cluster : 61816-61818
pushd %~dp0
@start "ActiveMQ (MS Cluster): 61816" /min MS\apache-activemq-61816\bin\win64\activemq.bat
@start "ActiveMQ (MS Cluster): 61817" /min MS\apache-activemq-61817\bin\win64\activemq.bat
@start "ActiveMQ (MS Cluster): 61818" /min MS\apache-activemq-61818\bin\win64\activemq.bat
popd
