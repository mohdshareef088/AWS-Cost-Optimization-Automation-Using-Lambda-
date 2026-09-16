
---
## 📘 **AWS Cost-Optimization Lambda Automation for EC2, RDS & EBS Cleanup**

## 🚀 Overview

This project provides a fully automated AWS Lambda function that:

- Stops EC2 instances tagged with `AutoStop=true`
- Stops RDS instances tagged with `AutoStop=true`
- Deletes EBS snapshots older than **7 days**
- Deletes **unattached** EBS volumes
- Sends a **daily cost & cleanup report** via **SNS email**
- Runs automatically using **CloudWatch Cron Scheduler**

---

## 📁 Project Structure overview

```
lambda-automation/
│
├── lambda_function.py        # Main Lambda logic
├── sns_report.py             # SNS email sender            
└── cloudwatch-cron.json      # Cron schedule config
```

---

# 🌐 **Lambda Function**

```python
import boto3
from datetime import datetime, timedelta

ec2 = boto3.client('ec2')
rds = boto3.client('rds')
sns = boto3.client('sns')

SNS_TOPIC_ARN = "arn:aws:sns:ap-south-1:YOUR-ACCOUNT-ID:DailyCostReport"

def lambda_handler(event, context):

    report = []

    # 1. STOP EC2 INSTANCES WITH TAG AutoStop=true
    instances = ec2.describe_instances(
        Filters=[{'Name': 'tag:AutoStop', 'Values': ['true']}]
    )

    ec2_ids = []
    for reservation in instances['Reservations']:
        for instance in reservation['Instances']:
            ec2_ids.append(instance['InstanceId'])

    if ec2_ids:
        ec2.stop_instances(InstanceIds=ec2_ids)
        report.append(f"Stopped EC2 instances: {ec2_ids}")
    else:
        report.append("No EC2 instances to stop.")

    # 2. STOP RDS INSTANCES WITH TAG AutoStop=true
    rds_instances = rds.describe_db_instances()

    stopped_rds = []
    for db in rds_instances['DBInstances']:
        arn = db['DBInstanceArn']
        tags = rds.list_tags_for_resource(ResourceName=arn)['TagList']

        if any(t['Key'] == 'AutoStop' and t['Value'] == 'true' for t in tags):
            rds.stop_db_instance(DBInstanceIdentifier=db['DBInstanceIdentifier'])
            stopped_rds.append(db['DBInstanceIdentifier'])

    if stopped_rds:
        report.append(f"Stopped RDS instances: {stopped_rds}")
    else:
        report.append("No RDS instances to stop.")

    # 3. DELETE OLD SNAPSHOTS (older than 7 days)
    snapshots = ec2.describe_snapshots(OwnerIds=['self'])['Snapshots']
    cutoff = datetime.utcnow() - timedelta(days=7)

    deleted_snaps = []
    for snap in snapshots:
        start = snap['StartTime'].replace(tzinfo=None)
        if start < cutoff:
            ec2.delete_snapshot(SnapshotId=snap['SnapshotId'])
            deleted_snaps.append(snap['SnapshotId'])

    report.append(f"Deleted snapshots: {deleted_snaps or 'None'}")

    # 4. DELETE UNATTACHED EBS VOLUMES
    volumes = ec2.describe_volumes(
        Filters=[{'Name': 'status', 'Values': ['available']}]
    )['Volumes']

    deleted_vols = []
    for vol in volumes:
        ec2.delete_volume(VolumeId=vol['VolumeId'])
        deleted_vols.append(vol['VolumeId'])

    report.append(f"Deleted unattached volumes: {deleted_vols or 'None'}")

    # 5. SEND SNS EMAIL REPORT
    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject="Daily AWS Cleanup Report",
        Message="\n".join(report)
    )

    return {"status": "success", "details": report}
```

---

# 📧 **SNS Email Setup**

```python
SNS_TOPIC_ARN = "arn:aws:sns:ap-south-1:140447104913:DailyCostReport"
```

### 2️⃣ Add Email Subscription

SNS → Topic → Subscriptions → Create Subscription

- Protocol: **Email**
- Endpoint: **your email**

Confirm the email.

---

# ⏰ **CloudWatch Cron Schedule**

Go to:

**CloudWatch → EventBridge → Rules → Create Rule**

Choose **Schedule** and enter cron:

### ✔ Run every day at 8 PM

```
cron(0 20 * * ? *)
```

### ✔ Run every night at 2 AM

```
cron(0 2 * * ? *)
```

### ✔ Run every 30 minutes

```
cron(0/30 * * * ? *)
```

Attach your Lambda as the target.

---

# 🔐 **IAM Permissions Required**

Attach this policy to your Lambda role:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:StopInstances",
        "ec2:DescribeSnapshots",
        "ec2:DeleteSnapshot",
        "ec2:DescribeVolumes",
        "ec2:DeleteVolume",
        "rds:DescribeDBInstances",
        "rds:ListTagsForResource",
        "rds:StopDBInstance",
        "sns:Publish"
      ],
      "Resource": "*"
    }
  ]
}
```

---

# 🧪 **Testing the Lambda**

### Manual test:

Go to Lambda → Test → Create test event → Run.

Expected output:

```
{
  "status": "success",
  "details": [
    "Stopped EC2 instances: [...]",
    "Stopped RDS instances: [...]",
    "Deleted snapshots: [...]",
    "Deleted unattached volumes: [...]"
  ]
}
```

And you will receive an email report.

---

# 🏁 Final Notes

This automation is perfect for:

- Dev/Test environments  
- Reducing AWS monthly bills  
- Cleaning unused resources  
- Auto-shutdown outside business hours  
- Daily reporting  

---

If you want bro, I can also:

🔥 Add **Cost Explorer API** to show daily AWS cost  
🔥 Add **Slack notifications**  
🔥 Add **S3 logging**  
🔥 Add **Terraform version** of this automation  

Just tell me.
