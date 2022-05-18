#!/bin/bash
running=true
port=$1

#pour stopper le serveur
trap 'running=false; rm tmp/socket' SIGINT

while $running
do
  #ecris ce qu'il recoit via socket dans un fichier
  nc -l -w 1 -p $port >> tmp/socket
done
