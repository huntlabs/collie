#!/bin/bash
echo "start build!"

echo  -e  "\nbuild server :"
cd ./server
dub build -f
echo  -e "\nbuild clent :"
cd ../client
dub build

echo -e  "\nbuild over!"
