#!/usr/bin/env bash
set -euo pipefail

cd /data
exec ttyd -W -p 7681 bash
