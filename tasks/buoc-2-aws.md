# Bước 2 - Triển Khai Với AWS

Repository sử dụng Amazon S3 cho DVC và model artifact, EC2 cho FastAPI, IAM
role cho EC2, và GitHub OIDC cho GitHub Actions. Không lưu access key dài hạn
hoặc private key trong Git.

## 1. Biến Môi Trường

Ví dụ dùng Region Singapore. Tên bucket S3 phải là duy nhất.

```powershell
$env:AWS_DEFAULT_REGION="ap-southeast-1"
$env:ARTIFACT_BUCKET="income-lab-<account-id>-<ten-duy-nhat>"
```

Đăng nhập local bằng AWS CLI và kiểm tra identity. Nên dùng IAM role/user dành
cho quản trị, không dùng root cho công việc hằng ngày:

```powershell
aws login
aws sts get-caller-identity
```

## 2. Tạo S3 Bucket

```powershell
aws s3api create-bucket `
  --bucket $env:ARTIFACT_BUCKET `
  --region $env:AWS_DEFAULT_REGION `
  --create-bucket-configuration LocationConstraint=$env:AWS_DEFAULT_REGION

aws s3api put-public-access-block `
  --bucket $env:ARTIFACT_BUCKET `
  --public-access-block-configuration `
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

aws s3api put-bucket-encryption `
  --bucket $env:ARTIFACT_BUCKET `
  --server-side-encryption-configuration `
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws s3api put-bucket-versioning `
  --bucket $env:ARTIFACT_BUCKET `
  --versioning-configuration Status=Enabled
```

S3 phát sinh phí theo dung lượng, request và data transfer. Với lab, nên xóa
EC2 và dữ liệu S3 sau khi chấm xong nếu không còn sử dụng.

## 3. Cấu Hình DVC

```powershell
.\.venv\Scripts\dvc.exe remote add --force -d labstore "s3://$env:ARTIFACT_BUCKET/dvc"
.\.venv\Scripts\dvc.exe push
```

Luôn chạy `dvc push` trước `git push`. Workflow tự cấu hình cùng remote từ
GitHub secret `ARTIFACT_BUCKET` trước khi gọi `dvc pull`.

## 4. IAM Cho GitHub Actions

Tạo IAM OIDC provider cho `https://token.actions.githubusercontent.com`, audience
`sts.amazonaws.com`, sau đó tạo role với trust policy giới hạn đúng repository:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::<ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:holyspirit2207/K4-L3L4-Track2-Day21-PhamThanhSon-2A202602794-CI-CD-for-AI-Systems:*"
      }
    }
  }]
}
```

Policy đầy đủ cho S3 và SSM nằm tại
[`infra/aws/github-deploy-policy.json`](../infra/aws/github-deploy-policy.json).
Trust policy giới hạn đúng repository và nhánh `main` nằm tại
[`infra/aws/github-trust-policy.json`](../infra/aws/github-trust-policy.json).

Các định danh AWS được khai báo trong khối `env` của workflow: `AWS_ROLE_ARN`,
`ARTIFACT_BUCKET`, `AWS_REGION` và `EC2_INSTANCE_ID`. Chúng không phải thông tin xác
thực; GitHub chỉ nhận quyền tạm thời sau khi OIDC role kiểm tra đúng repository và
nhánh `main`. Không lưu access key hoặc secret key trong mã nguồn.

## 5. EC2 Và IAM Instance Role

Tạo Ubuntu EC2, gắn Elastic IP nếu cần địa chỉ ổn định, và chỉ mở TCP 8080
từ các nguồn thực sự cần truy cập. Không cần mở SSH: workflow triển khai bằng
AWS Systems Manager. Gắn `AmazonSSMManagedInstanceCore` cùng quyền S3 tối thiểu:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "s3:GetObject",
    "Resource": [
      "arn:aws:s3:::<BUCKET_NAME>/artifacts/current/model.joblib",
      "arn:aws:s3:::<BUCKET_NAME>/deploy/current/*"
    ]
  }]
}
```

Trên EC2:

```bash
sudo apt update
sudo apt install -y python3-venv
mkdir -p ~/income-api/src ~/models
python3 -m venv ~/income-api/.venv
~/income-api/.venv/bin/pip install fastapi==0.111.0 uvicorn==0.29.0 \
  scikit-learn==1.4.2 joblib==1.4.2 boto3==1.43.106
```

Chép `src/serve.py` vào `~/income-api/src/serve.py`, rồi tạo service:

```ini
[Unit]
Description=Income Model Inference Server
After=network-online.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/income-api
Environment="ARTIFACT_BUCKET=<BUCKET_NAME>"
Environment="AWS_DEFAULT_REGION=ap-southeast-1"
ExecStart=/home/ubuntu/income-api/.venv/bin/uvicorn src.serve:app --host 0.0.0.0 --port 8080
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
```

Lưu tại `/etc/systemd/system/income-api.service`, sau đó:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now income-api
sudo systemctl status income-api
```

EC2 nhận credentials tạm thời từ instance role; không đặt
`AWS_ACCESS_KEY_ID` hoặc `AWS_SECRET_ACCESS_KEY` trong systemd.

## 6. Kiểm Tra

```powershell
aws s3 ls "s3://$env:ARTIFACT_BUCKET/dvc/"
aws s3 ls "s3://$env:ARTIFACT_BUCKET/artifacts/current/"
curl.exe "http://<EC2_IP>:8080/healthz"
curl.exe -X POST "http://<EC2_IP>:8080/score" `
  -H "Content-Type: application/json" `
  -d '{"features":[28,2,14,2,11,0,1,0,0,45]}'
```

Để theo dõi truy cập, bật CloudTrail data events cho bucket và CloudWatch
metrics/alarms phù hợp. Mã hóa log destination và giữ S3 Block Public Access.

## 7. Dọn Tài Nguyên Sau Khi Chấm

EC2, EBS, S3 storage/request và CloudTrail data events có thể phát sinh phí.
Sau khi đã nộp đủ ảnh và không còn cần demo, terminate instance trước:

```powershell
aws ec2 terminate-instances --instance-ids <INSTANCE_ID>
aws ec2 wait instance-terminated --instance-ids <INSTANCE_ID>
```

Chỉ xóa bucket sau khi chắc chắn không cần DVC/model nữa. Vì bucket bật
versioning, cần xóa cả object versions và delete markers trước khi xóa bucket.
