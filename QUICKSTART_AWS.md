# Church Services App - Quick Start Guide (AWS + Cloudflare)

## 📋 Before You Begin

### What You'll Need

**1. AWS Account**
- AWS Access Key ID and Secret Access Key
- Permissions for S3 and SES
- Get credentials: https://console.aws.amazon.com/iam/home#/security_credentials

**2. Cloudflare Account (Free Plan Works!)**
- Domain added to Cloudflare
- Cloudflare API Token
- Zone ID for your domain
- Get these at: https://dash.cloudflare.com

**3. AWS Lightsail Instance**
- Ubuntu 22.04 or 24.04 LTS
- Minimum 2GB RAM
- Static IP assigned
- SSH access configured

**4. Domain Name**
- Domain registered and added to Cloudflare
- DNS will be configured during setup

---

## 🚀 Installation (Interactive Mode)

### Step 1: Upload Files to Server

```bash
# From your local machine
scp install.sh setup-app.sh create-migrations.sh ubuntu@YOUR_SERVER_IP:~/
scp -r migrations DatabaseSeeder.php ubuntu@YOUR_SERVER_IP:~/
```

### Step 2: SSH into Server

```bash
ssh ubuntu@YOUR_SERVER_IP
```

### Step 3: Run Interactive Installation

```bash
sudo bash install.sh
```

The installer will guide you through:

**Application Settings:**
- Church/Organization name
- Domain name (e.g., church.example.com)
- Admin email address

**Database Settings:**
- Database password (minimum 16 characters)

**AWS Configuration:**
- AWS Region (default: us-east-1)
- AWS Access Key ID
- AWS Secret Access Key
- S3 Bucket name (will be created automatically)

**AWS SES Configuration:**
- 'From' email address (e.g., noreply@church.example.com)
- 'From' name (e.g., "First Church")

**Cloudflare Configuration:**
- Cloudflare account email
- Cloudflare API Token
- Cloudflare Zone ID

**What Gets Installed:**
- ✓ Nginx web server
- ✓ PHP 8.3 + extensions
- ✓ PostgreSQL database
- ✓ Redis server
- ✓ Node.js 20.x
- ✓ AWS CLI v2
- ✓ S3 bucket (created and configured)
- ✓ Supervisor

**Installation Time:** ~10-15 minutes

---

## ☁️ Step 4: Configure Cloudflare

### 4.1 Set DNS Records

Log into Cloudflare dashboard and add an A record:

```
Type: A
Name: @ (or your subdomain)
IPv4: YOUR_SERVER_IP
Proxy status: Proxied (orange cloud icon)
TTL: Auto
```

### 4.2: Configure SSL/TLS

1. Go to SSL/TLS tab
2. Set encryption mode to **"Full (strict)"**
3. Enable "Always Use HTTPS"
4. Enable "Automatic HTTPS Rewrites"

### 4.3: Configure Security

**Recommended Settings:**
1. **Firewall Rules** → Create rule to allow only HTTP/HTTPS
2. **Security Level** → Set to "Medium"
3. **Challenge Passage** → 30 minutes
4. **Browser Integrity Check** → Enable

### 4.4: Configure Speed

1. **Auto Minify** → Enable CSS, HTML, JS
2. **Brotli** → Enable
3. **HTTP/2** → Enable
4. **HTTP/3** → Enable (recommended)

**DNS Propagation:** Wait 5-10 minutes after DNS changes

---

## 📧 Step 5: Configure AWS SES

### 5.1: Verify Email Address

1. Visit: https://console.aws.amazon.com/ses/
2. Select your region (same as chosen during install)
3. Go to **Email Addresses** → **Verify a New Email Address**
4. Enter your "From" email address
5. Check your email and click verification link

### 5.2: Move Out of Sandbox (For Production)

In SES sandbox mode, you can only send to verified emails. To send to anyone:

1. **Request Production Access**
2. Provide use case description
3. Approval usually takes 24-48 hours

**For Testing:** You can verify additional email addresses to test in sandbox mode.

---

## 🖥️ Step 6: Run Application Setup

```bash
cd /var/www/church-services
bash ~/setup-app.sh
```

This will:
- Create Laravel project
- Install all dependencies
- Configure for AWS S3 storage
- Configure for AWS SES email
- Set up WebSockets
- Configure Vue.js frontend

**Setup Time:** ~5-10 minutes

---

## 💾 Step 7: Database Setup

```bash
cd /var/www/church-services

# Copy migrations
cp ~/migrations/*.php database/migrations/

# Copy seeder
cp ~/DatabaseSeeder.php database/seeders/

# Run migrations
php artisan migrate

# Seed sample data
php artisan db:seed
```

**Sample Data Includes:**
- 5 users (admin + team leaders + volunteers)
- 3 service types
- 3 teams
- 4 popular worship songs

---

## 🎨 Step 8: Build Frontend

```bash
cd /var/www/church-services

# Production build
npm run build
```

**Build Time:** ~2-3 minutes

---

## ▶️ Step 9: Start Services

```bash
# Start all background services
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start all

# Verify services are running
sudo supervisorctl status
```

**Expected Output:**
```
church-services-websocket    RUNNING
church-services-worker:0     RUNNING
church-services-worker:1     RUNNING
```

---

## 🎉 Step 10: Access Your Application

Open your browser and visit: `https://your-domain.com`

**Default Login Credentials:**
- Email: `admin@church.local`
- Password: `password`

**⚠️ IMPORTANT: Change this password immediately!**

---

## ✅ Post-Installation Checklist

### Security
- [ ] Changed default admin password
- [ ] Changed database password from default
- [ ] Verified all users have strong passwords
- [ ] Reviewed Cloudflare firewall rules
- [ ] Enabled Cloudflare Bot Fight Mode

### AWS
- [ ] Verified SES email address
- [ ] Tested email sending
- [ ] Confirmed S3 bucket is private
- [ ] Checked S3 CORS configuration
- [ ] Reviewed AWS costs/billing alerts

### Application
- [ ] Created additional user accounts
- [ ] Configured service types
- [ ] Added teams
- [ ] Imported songs
- [ ] Created first service plan
- [ ] Tested chat functionality
- [ ] Tested file uploads (they go to S3!)

### Backups
- [ ] Database backup configured
- [ ] S3 versioning enabled (auto-configured)
- [ ] Tested restore procedure

---

## 🧪 Testing Your Setup

### Test Email (AWS SES)

```bash
cd /var/www/church-services
php artisan tinker
```

Then in tinker:
```php
Mail::raw('Test email from Church Services App', function($msg) {
    $msg->to('your-email@example.com')->subject('Test Email');
});
exit
```

### Test File Upload (AWS S3)

1. Log into the application
2. Go to Songs
3. Create a new song
4. Upload a chord chart (PDF) or audio file
5. File will be stored in S3 automatically!

### Test Real-time Chat

1. Open app in two different browsers
2. Navigate to a service plan
3. Open the chat
4. Send messages - they should appear instantly in both browsers!

### Test Cloudflare

1. Check your server logs: `sudo tail -f /var/log/nginx/access.log`
2. Visit your site in a browser
3. You should see Cloudflare IP addresses (173.245.x.x, etc.) not visitor IPs
4. Check response headers for Cloudflare headers (CF-RAY, etc.)

---

## 📊 Configuration Files

### Application Config
**Location:** `~/.church-services-config`

Contains all your settings (AWS credentials, passwords, etc.)
**⚠️ Keep this file secure! Never commit to Git.**

### Laravel Environment
**Location:** `/var/www/church-services/.env`

All application configuration including:
- Database credentials
- AWS credentials
- S3 bucket name
- SES configuration
- App URL and name

### Nginx Configuration
**Location:** `/etc/nginx/sites-available/church-services`

Web server configuration with Cloudflare real IP support

### AWS CLI Configuration
**Location:** `~/.aws/credentials` and `~/.aws/config`

AWS CLI automatically configured during installation

---

## 🔄 Updating Cloudflare IPs

Cloudflare occasionally adds new IP ranges. The installer set up automatic updates:

**Manual Update:**
```bash
sudo /usr/local/bin/update-cloudflare-ips.sh
```

**Automatic:** Runs every Sunday at 3 AM via cron

---

## 📈 Monitoring

### Check Service Status

```bash
# All services
sudo supervisorctl status

# Specific service
sudo supervisorctl status church-services-websocket
```

### View Logs

```bash
# Application logs
tail -f /var/www/church-services/storage/logs/laravel.log

# WebSocket logs
sudo tail -f /var/log/church-services/websocket.log

# Queue worker logs
sudo tail -f /var/log/church-services/worker.log

# Nginx access
sudo tail -f /var/log/nginx/access.log

# Nginx errors
sudo tail -f /var/log/nginx/error.log
```

### Check S3 Usage

```bash
aws s3 ls s3://your-bucket-name --recursive --human-readable --summarize
```

### Check SES Statistics

Visit: https://console.aws.amazon.com/ses/home#dashboard:

---

## 💰 Cost Breakdown

### Monthly Costs (Estimated)

**AWS Lightsail:**
- 2GB Instance: $10/month
- 4GB Instance: $20/month (if you need more power)

**AWS S3:**
- First 50 TB / month: $0.023 per GB
- ~100GB storage: ~$2.30/month
- Data transfer OUT: First 1 GB free, then $0.09/GB

**AWS SES:**
- First 62,000 emails/month: FREE (if sent from EC2/Lightsail)
- After that: $0.10 per 1,000 emails

**Cloudflare:**
- Free plan: $0/month (plenty for most churches)
- Pro plan: $20/month (optional, for extra features)

**Domain:**
- $10-15/year

**Total: ~$11-35/month** (depending on usage)

**Compare to SaaS alternatives:** $50-150/month

**Annual Savings: $468-1,380**

---

## 🐛 Troubleshooting

### Can't Connect to Site

1. Check Cloudflare DNS propagation: https://www.whatsmydns.net/
2. Verify A record points to correct IP
3. Check if Cloudflare proxy is enabled (orange cloud)
4. Wait 10 minutes for DNS propagation

### Emails Not Sending

1. Verify SES email address in AWS console
2. Check if still in SES sandbox
3. Review logs: `tail -f /var/www/church-services/storage/logs/laravel.log`
4. Test SES connection: `php artisan tinker` then try sending mail

### File Uploads Failing

1. Check S3 bucket permissions
2. Verify AWS credentials in `.env`
3. Test S3 connection: `aws s3 ls s3://your-bucket-name`
4. Check Laravel logs for errors

### WebSocket Not Connecting

1. Check service status: `sudo supervisorctl status church-services-websocket`
2. Restart service: `sudo supervisorctl restart church-services-websocket`
3. Check logs: `sudo tail -f /var/log/church-services/websocket.log`
4. Verify port 6001 is open in firewall

### Cloudflare 520/521/522 Errors

1. Check Nginx is running: `sudo systemctl status nginx`
2. Check SSL mode is "Full (strict)" in Cloudflare
3. Restart Nginx: `sudo systemctl restart nginx`
4. Check Nginx logs for errors

---

## 🎯 Next Steps

### Customize Your Installation

1. **Update Branding**
   - Edit company name in settings
   - Upload church logo
   - Customize colors in Tailwind config

2. **Import Your Data**
   - Add your songs to library
   - Create your service types
   - Set up your teams
   - Add all volunteers

3. **Create First Service**
   - Schedule a service
   - Add service items
   - Assign volunteers
   - Build presentation

4. **Train Your Team**
   - Create user accounts for staff
   - Provide training on features
   - Set up team workflows

### Optional Enhancements

- [ ] Set up automatic database backups to S3
- [ ] Configure monitoring/uptime checks
- [ ] Set up staging environment
- [ ] Add two-factor authentication
- [ ] Integrate with church website
- [ ] Set up CloudWatch alarms for AWS
- [ ] Configure Cloudflare WAF rules

---

## 📞 Getting Help

**Configuration Issues:**
- Check `~/.church-services-config`
- Review `/var/www/church-services/.env`

**AWS Issues:**
- Visit AWS Console
- Check CloudWatch logs
- Review IAM permissions

**Cloudflare Issues:**
- Check Cloudflare dashboard
- Review firewall rules
- Check SSL/TLS settings

**Application Issues:**
- Check Laravel logs: `/var/www/church-services/storage/logs/`
- Review system logs: `/var/log/church-services/`

---

## 🎊 Congratulations!

Your church services production app is now:
- ✅ Fully installed and configured
- ✅ Using AWS S3 for file storage
- ✅ Using AWS SES for email delivery
- ✅ Protected and accelerated by Cloudflare
- ✅ Ready for your team to use!

**Access your app:** https://your-domain.com

**Default login:** admin@church.local / password

**Remember to:**
1. Change default passwords
2. Add your team members
3. Configure your services
4. Start planning!

---

Built with ❤️ for churches worldwide
