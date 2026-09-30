
---
## 📘**AWS Cost-Optimization Automation (Lambda + EventBridge + SNS)**

📌Automated system using Lambda, EventBridge, and SNS. This project runs daily and performs stale resource identification and cleanup tasks, such as stopping and deleting tagged resources 

## 📦 Features
```
├──Stop idle EC2 instances
├──Stop unused RDS instances
├──Delete old EBS snapshots
├──Delete unattached EBS volumes
├──Daily SNS email report
├──Automated scheduling via EventBridge
├──IAM roles for secure execution
```
## 🚀 Architecture Overview
```
Scheduled EventBridge Rule (cron)
        |
        v
   Lambda Function
        |
        |--- Stop EC2
        |--- Stop RDS
        |--- Delete old snapshots
        |--- Delete unused EBS volumes
        |
        v
       SNS → Email Notification
```
----
## ⚙️Deployment Steps

```
Create a Lambda function and upload Python code that
├──Checks EC2, RDS, EBS resources
├──Performs cleanup
├──Sends an SNS report
Attach an IAM role to access required resources
Create an EventBridge schedule that triggers the **Lambda function** on a schedule (daily).
Stops tagged resources with **AutoStop=true**
Test Lambda manually; it performs cleanup.
Create an SNS Topic subscribing to the email. Verify the SNS email.
SNS sends a **daily cost & cleanup report** summarizing the cleanup, and you receive a daily summary in your inbox
Push to GitHub
```
----
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
# 📸 Screenshots

Roles

<img width="1844" height="818" alt="image" src="https://github.com/user-attachments/assets/e0331721-7536-473b-b9f5-0460936f66f9" />


# 🌐 **🔐IAM Permissions Required**

Policies for the Lambda execution role:
```
├──AmazonEC2FullAccess
├──AmazonRDSFullAccess
├──AmazonSNSFullAccess
├──AWSLambdaBasicExecutionRole

```
```
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
                "ec2:DescribeTags"
                "sns:Publish"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "rds:DescribeDBInstances",
                "rds:ListTagsForResource",
                "rds:StopDBInstance"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
```

---

## ⏰**EventBridge Rule Cron Schedule**

### ✔ Run every 30 minutes
cron(0/30 * * * ? *)

<img width="1732" height="793" alt="image" src="https://github.com/user-attachments/assets/507fde31-feb7-4ae9-b3a5-a745063d7ab0" />

---
---
# 🧪 **Testing the Lambda**

### Manual test:

Go to Lambda → Test → Create test event → Run.

Expected output:

<img width="1582" height="663" alt="image" src="https://github.com/user-attachments/assets/cfae9c70-047d-415b-9ee2-e66dfb6cdb32" />

---
---
# Lambda Execution Logs

<img width="1857" height="667" alt="image" src="https://github.com/user-attachments/assets/c07261a6-8a38-4035-84d5-fdec9b3a78aa" />

---

# 📧 **SNS Email Setup**

```python
SNS_TOPIC_ARN = "arn:aws:sns:ap-south-1:140447104913:DailyCostReport"
```
---

### 2️⃣ Adding Email Subscription

SNS → Topic → Subscriptions → Create Subscription

<img width="1404" height="626" alt="image" src="https://github.com/user-attachments/assets/991c54ff-ef7d-4b77-a53a-195d263c984e" />

Confirm the email.
<img width="919" height="506" alt="image" src="https://github.com/user-attachments/assets/152ccbde-0533-48ed-aea9-b6bff3d97eff" />

# SNS Email Report
---
You will also receive an email report.

<img width="1888" height="672" alt="image" src="https://github.com/user-attachments/assets/30ad3e6e-2c41-49fc-9ef6-dd4a70f8afb0" />
---

