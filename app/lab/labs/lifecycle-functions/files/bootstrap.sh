#!/bin/bash
yum install -y jq
systemctl start orders-worker
