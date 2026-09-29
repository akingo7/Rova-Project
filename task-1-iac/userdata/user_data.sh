#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

cat <<'EOF' > /var/www/html/index.html
${html_content}
EOF

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
AZ=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)

sed -i "s/__INSTANCE_ID__/$INSTANCE_ID/g" /var/www/html/index.html
sed -i "s/__AVAILABILITY_ZONE__/$AZ/g" /var/www/html/index.html
