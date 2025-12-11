# Complete SSH Setup Guide for Nvidia DGX Spark
## Local & Remote Access Configuration

---

## Part 1: Prerequisites

### On DGX Spark Machine
- Ubuntu/Debian OS installed
- Network connectivity (already have 192.168.0.122)
- Administrator/sudo access
- Tailscale account (personal free plan)

### On Your Local Machine (Office & Remote)
- SSH client installed (built-in on Linux/Mac, PuTTY or built-in on Windows 10+)
- Tailscale account (same as DGX)

---

## Part 2: Setup SSH Server on DGX Spark

### Step 1: Verify SSH Service

Connect to DGX directly or through existing access, then run:

```bash
# Check if SSH is running
sudo systemctl status ssh
```

If not active, install and start it:

```bash
sudo apt update
sudo apt install openssh-server openssh-client
sudo systemctl enable ssh
sudo systemctl start ssh
```

### Step 2: Secure SSH Configuration

Edit the SSH config file:

```bash
sudo nano /etc/ssh/sshd_config
```

Locate and modify these lines (uncomment if needed):

```
Port 22
Protocol 2
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication yes
MaxAuthTries 3
```

Save and restart SSH:

```bash
sudo systemctl restart ssh
```

### Step 3: Set Up Key-Based Authentication

On your local machine, generate an SSH key pair (if you don't have one):

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

Copy the public key to DGX Spark:

```bash
ssh-copy-id -i ~/.ssh/id_rsa.pub your_username@192.168.0.122
```

When prompted, enter your password on the DGX Spark.

Verify the key was added:

```bash
ssh your_username@192.168.0.122 "cat ~/.ssh/authorized_keys"
```

---

## Part 3: LOCAL ACCESS (Same Office Network)

### Direct SSH Connection

From any machine on your office network (192.168.0.x):

```bash
ssh your_username@192.168.0.122
```

Or if using a non-standard port, add `-p`:

```bash
ssh your_username@192.168.0.122 -p 22
```

### Simplify with SSH Config

Create/edit `~/.ssh/config` on your local machine:

```
Host dgx-spark
    HostName 192.168.0.122
    User your_username
    IdentityFile ~/.ssh/id_rsa
    Port 22
```

Then simply use:

```bash
ssh dgx-spark
```

### Verify Local Access

From your office network:

```bash
# Test connection
ssh dgx-spark

# You should see the DGX prompt
# If successful, close with: exit
```

---

## Part 4: REMOTE ACCESS (Outside Office) - Tailscale Setup

### Step 1: Install Tailscale on DGX Spark

```bash
curl -fsSL https://tailscale.com/install.sh | sh

# Enable and start the service
sudo systemctl enable tailscaled
sudo systemctl start tailscaled
```

### Step 2: Authenticate DGX to Tailscale

```bash
sudo tailscale up
```

Output will show:
```
To authenticate, visit:

    https://login.tailscale.com/a/xxxxxxx
```

Open that URL in your browser, sign in with your Tailscale account (personal plan), and authorize the device.

### Step 3: Get DGX's Tailscale IP

```bash
tailscale ip -4
```

Output will be something like: `100.x.x.x`

**Save this IP** - you'll use it for remote access.

### Step 4: Install Tailscale on Your Remote Machine

On the machine you'll use to access from outside the office:

**Linux/Mac:**
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo systemctl enable tailscaled
sudo systemctl start tailscaled
sudo tailscale up
```

**Windows 10+:**
- Download from https://tailscale.com/download
- Install and sign in with the same Tailscale account

### Step 5: Test Remote Connection

From outside your office network, on your remote machine:

```bash
ssh your_username@100.x.x.x
```

Replace `100.x.x.x` with the actual Tailscale IP from Step 3.

---

## Part 5: Simplified Remote SSH Config (Recommended)

Add this to your `~/.ssh/config` on your remote machine:

```
Host dgx-spark-remote
    HostName 100.x.x.x
    User your_username
    IdentityFile ~/.ssh/id_rsa
    Port 22
```

Then from anywhere with Tailscale running:

```bash
ssh dgx-spark-remote
```

---

## Part 6: Verification Checklist

### Local Access (Office Network)

- [ ] Can SSH into DGX directly: `ssh dgx-spark`
- [ ] Can execute commands: `ssh dgx-spark "nvidia-smi"`
- [ ] Can exit without errors

### Remote Access (Outside Office)

- [ ] Tailscale is running on DGX: `sudo systemctl status tailscaled`
- [ ] Tailscale is running on remote machine
- [ ] Can see DGX IP: `tailscale ip -4`
- [ ] Can ping DGX over Tailscale: `ping 100.x.x.x`
- [ ] Can SSH into DGX: `ssh dgx-spark-remote`

### Full System Test

```bash
# From remote location, test complete access
ssh dgx-spark-remote "nvidia-smi"
ssh dgx-spark-remote "ollama list"
ssh dgx-spark-remote "docker ps"
```

---

## Part 7: Troubleshooting

### Can't SSH Locally

```bash
# Check SSH is running
sudo systemctl status ssh

# Check SSH is listening
sudo ss -tlnp | grep ssh

# Verify firewall
sudo ufw status
sudo ufw allow 22/tcp
```

### Can't Connect Remotely

```bash
# On DGX - check Tailscale status
sudo tailscale status

# Verify Tailscale is running
sudo systemctl status tailscaled

# Check connectivity
ping 100.x.x.x  # from remote machine
```

### Permission Denied

```bash
# Fix SSH key permissions on DGX
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys

# Verify public key was copied correctly
cat ~/.ssh/authorized_keys
```

---

## Part 8: Security Best Practices

1. **Key-based authentication only** (done above)
2. **Disable password authentication** (optional, for advanced users):
   ```bash
   # Edit /etc/ssh/sshd_config
   PasswordAuthentication no
   sudo systemctl restart ssh
   ```

3. **Monitor access**:
   ```bash
   # Check login history
   last -n 10
   ```

4. **Tailscale security**: Your connections are encrypted end-to-end. Tailscale handles all network routing securely.

---

## Summary

| Access Type | Command | Location | Status |
|---|---|---|---|
| **Local (Office)** | `ssh dgx-spark` | 192.168.0.122 | Direct |
| **Remote (Outside)** | `ssh dgx-spark-remote` | 100.x.x.x (Tailscale) | Via VPN |

Both methods use the same SSH key and username. The difference is the IP address: local network vs. Tailscale network.

---

## Quick Reference

```bash
# Setup (one-time on DGX)
sudo apt install openssh-server
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Setup (one-time on remote machine)
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Access from office
ssh dgx-spark

# Access from anywhere
ssh dgx-spark-remote

# Get Tailscale IP anytime
tailscale ip -4
```

---

**You're all set! Both local and remote SSH access is now ready to use.**
