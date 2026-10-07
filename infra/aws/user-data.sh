#!/bin/bash
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive
export AWS_DEFAULT_REGION=ap-southeast-1
BUCKET=income-lab-147435198681-2a202602794
APP_DIR=/home/ubuntu/income-api

apt-get update
apt-get install -y python3-venv awscli curl

mkdir -p "$APP_DIR/src" /home/ubuntu/models
aws s3 cp "s3://${BUCKET}/deploy/current/serve.py" "$APP_DIR/src/serve.py"
aws s3 cp "s3://${BUCKET}/deploy/current/requirements-serving.txt" "$APP_DIR/requirements-serving.txt"

python3 -m venv "$APP_DIR/.venv"
"$APP_DIR/.venv/bin/pip" install --upgrade pip
"$APP_DIR/.venv/bin/pip" install -r "$APP_DIR/requirements-serving.txt"
chown -R ubuntu:ubuntu "$APP_DIR" /home/ubuntu/models

cat >/etc/systemd/system/income-api.service <<EOF
[Unit]
Description=Income Model Inference Server
After=network-online.target
Wants=network-online.target

[Service]
User=ubuntu
WorkingDirectory=$APP_DIR
Environment="ARTIFACT_BUCKET=$BUCKET"
Environment="AWS_DEFAULT_REGION=ap-southeast-1"
ExecStart=$APP_DIR/.venv/bin/uvicorn src.serve:app --host 0.0.0.0 --port 8080
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now income-api
