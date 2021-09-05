@echo off
echo Starting Zookeeper Cluster: 2181-2183
pushd %~dp0
@start "Zookeeper (Cluster): 2181" /min apache-zookeeper-2181\bin\zkServer.cmd
@start "Zookeeper (Cluster): 2182" /min apache-zookeeper-2182\bin\zkServer.cmd
@start "Zookeeper (Cluster): 2183" /min apache-zookeeper-2183\bin\zkServer.cmd
popd
