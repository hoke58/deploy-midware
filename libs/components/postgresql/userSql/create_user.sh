#!/bin/bash

# 固定文件名称和路径，请勿修改

User="TTestUser"
Passwd="pguser123"
docker exec -u postgres postgresql psql -c "create user ${User} with password "\'${Passwd}\'";"
