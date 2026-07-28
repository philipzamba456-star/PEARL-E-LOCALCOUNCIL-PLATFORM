# PHASE 13: RUNNING ON ORACLE CLOUD (ALWAYS FREE) — STEP BY STEP

Everything below uses Oracle Cloud's **Always Free** tier — no credit card
charges, free forever, and it keeps your database and your app host in the
same ecosystem so there's no cross-cloud networking to fight with.

You'll end up with:
- An **Autonomous Database** (Oracle DB + APEX, if you also want that)
- A small **Compute VM** running the Node.js app from the zip/repo I gave you
- A public URL anyone can log into and use

Budget ~45–60 minutes for a first pass.

---

## Part 1 — Create your OCI account

1. Go to https://signup.oraclecloud.com
2. Sign up (email verification + a card for identity verification only —
   Always Free resources are never charged).
3. Once in, note your **tenancy region** (shown top-right) — pick one close
   to you and stick with it for everything below.

---

## Part 2 — Create the Autonomous Database

1. Console (hamburger menu, top-left) → **Oracle Database → Autonomous Database → Create Autonomous Database**
2. Fill in:
   - Display name / DB name: `pearlscouncil`
   - Workload type: **Transaction Processing**
   - Deployment type: **Serverless**
   - **Always Free**: toggle ON (this is the important one — keeps it free)
   - Set an **ADMIN password** — write it down, you'll need it once now and never again after setup
   - Network access: **Secure access from everywhere** (simplest; you can lock this down to specific IPs later under Network settings)
3. Click **Create Autonomous Database**. Takes a couple of minutes to provision.

### Load your schema
1. Once it's "Available," click into it → **Database Actions → SQL**
   (this opens a browser-based SQL Worksheet — no client install needed)
2. First, create the app's own schema user (don't build in ADMIN):
   ```sql
   CREATE USER pearls_app IDENTIFIED BY "ChooseAStrongPassword1";
   GRANT CONNECT, RESOURCE, CREATE VIEW, CREATE SEQUENCE, CREATE TRIGGER, CREATE PROCEDURE TO pearls_app;
   ALTER USER pearls_app QUOTA UNLIMITED ON USERS;
   ```
3. Log out of ADMIN, log back into **Database Actions → SQL** as `pearls_app`
   (there's a user switcher, or reopen Database Actions and pick SQL under
   that schema).
4. Paste and run each script from `server/sql/`, **in this exact order**
   (SQL Worksheet lets you paste multiple statements and run the whole
   script at once — use the ▶ "Run Script" button, not just "Run
   Statement", since these have PL/SQL blocks):
   ```
   Phase5_01_Sequences_and_Tables.sql
   Phase5_02_Indexes.sql
   Phase5_03_Views.sql
   Phase5_04_Seed_Data.sql
   Phase6_01_Package_Specs.sql
   Phase6_02_Package_Bodies.sql
   Phase6_03_Triggers.sql
   Phase6_04_Standalone_Procs_Functions.sql
   Phase9_01_Database_Security_v3.sql
   Phase11_App_Enhancements.sql
   ```

### Get your connection string
1. Autonomous Database page → **Database Connection**
2. Under **TLS Authentication**, you can connect **without a wallet file**
   using a plain connect string (simplest for node-oracledb's THIN driver).
   Copy the connection string labeled `..._high` (or `_medium` — `_high`
   is fine for this app's traffic level), e.g.:
   ```
   pearlscouncil_high
   ```
   or the long form:
   ```
   (description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=adb.<region>.oraclecloud.com))(connect_data=(service_name=<xyz>_pearlscouncil_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))
   ```
   Save this — it becomes `ORACLE_CONNECT_STRING` in your `.env`.

---

## Part 3 — Create the Compute VM to run the Node app

1. Console → **Compute → Instances → Create Instance**
2. Name: `pearls-app-host`
3. Image: **Canonical Ubuntu 22.04** (or the default "Always Free-eligible" image shown)
4. Shape: make sure it says **"Always Free-eligible"** next to the shape (VM.Standard.E2.1.Micro, or the Ampere ARM Always Free shape — either works)
5. Networking: use the default VCN, and under **Add SSH keys**, either upload
   your public key or generate one and download the private key (you need
   this to log in)
6. Create Instance. Once running, note its **Public IP address**.

### Open the port for the app
1. Go to the instance's **Subnet → Security List → Ingress Rules → Add Ingress Rule**
2. Source CIDR: `0.0.0.0/0`, IP Protocol: TCP, Destination Port: `3000`
   (or `80` if you set up a reverse proxy later — start with 3000 to keep it simple)
3. Also, on the VM itself (Ubuntu's own firewall), once you're logged in:
   ```bash
   sudo iptables -I INPUT -p tcp --dport 3000 -j ACCEPT
   sudo netfilter-persistent save   # if installed; otherwise this rule needs re-adding on reboot
   ```

### Log in and set up Node
```bash
ssh -i /path/to/your/private_key.key ubuntu@<PUBLIC_IP>

sudo apt update && sudo apt install -y nodejs npm git
node -v   # confirm Node 18+; if it's older, use nvm to install Node 20:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.bashrc
nvm install 20
```

### Get the app onto the VM
Either clone from the GitHub repo (if you pushed it per the earlier steps):
```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git pearls-app
cd pearls-app/server
```
...or `scp` the zip up and unzip it:
```bash
# from your own machine, not the VM:
scp -i /path/to/private_key.key pearls-e-local-council-webapp.zip ubuntu@<PUBLIC_IP>:~
# then on the VM:
unzip pearls-e-local-council-webapp.zip -d pearls-app
cd pearls-app/server
```

### Configure and install
```bash
cp .env.example .env
nano .env
```
Fill in:
```
ORACLE_CONNECT_STRING=<the connect string you copied in Part 2>
ORACLE_USER=pearls_app
ORACLE_PASSWORD=<the password you set for pearls_app>
PORT=3000
JWT_SECRET=<generate one: openssl rand -hex 32>
CORS_ORIGIN=http://<PUBLIC_IP>:3000
```
Then:
```bash
npm install
npm run set-admin-password admin YourChosenAdminPassword123
```

### Run it (properly — as a persistent service, not just `npm start` in your SSH session)
```bash
sudo npm install -g pm2
pm2 start src/server.js --name pearls-council
pm2 save
pm2 startup    # follow the printed command to enable start-on-boot
```

Visit `http://<PUBLIC_IP>:3000` — that's it, live.

---

## Part 4 — Put it behind a real domain + HTTPS (recommended before real use)

1. Point a domain's DNS A record at your VM's public IP.
2. Install Caddy (simplest automatic-HTTPS reverse proxy):
   ```bash
   sudo apt install -y caddy
   sudo tee /etc/caddy/Caddyfile <<EOF
   yourdomain.com {
       reverse_proxy localhost:3000
   }
   EOF
   sudo systemctl restart caddy
   ```
3. Now open port 443 (and 80) instead of 3000 in the Security List, and set
   `CORS_ORIGIN=https://yourdomain.com` in `.env`, then `pm2 restart pearls-council`.

---

## Quick sanity checklist if something doesn't connect

- `pm2 logs pearls-council` — shows Node/Oracle connection errors directly.
- "ORA-12154" or similar TNS errors → double-check `ORACLE_CONNECT_STRING`
  was copied exactly, including the `tcps` protocol and port `1522`.
- Can't reach the site at all → check both the OCI Security List ingress
  rule *and* the VM's own `iptables`/`ufw` — OCI blocks at two layers.
- "ORA-01017 invalid username/password" → the `pearls_app` user/password in
  `.env` don't match what you created in Part 2.

---

## If you'd rather I push the code to GitHub for you first

I still don't have your GitHub or OCI credentials, but if you paste me a
short-lived, repo-scoped GitHub token as I mentioned, I can push the commit
I already prepared, so `git clone` in Part 3 above just works — saves you
the zip/scp step. Otherwise, the zip file works exactly the same.
