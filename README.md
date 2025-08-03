# Raspberry Pi WiFi Hotspot Setup

A comprehensive guide and automated setup script for creating a WiFi hotspot/access point on Raspberry Pi using hostapd and dnsmasq.

## �� Features

- **Easy Setup**: Automated script for quick deployment
- **Secure**: WPA2 encryption with customizable passwords
- **DHCP Server**: Automatic IP assignment for connected devices
- **Internet Sharing**: Route internet traffic from ethernet to WiFi
- **Persistent**: Survives reboots and system updates
- **Monitoring**: Built-in tools for monitoring connected devices

## 📋 Prerequisites

- Raspberry Pi (any model with WiFi capability)
- MicroSD card with Raspberry Pi OS
- Internet connection for initial setup
- Basic Linux command line knowledge

## 🛠️ Quick Start

### Option 1: Automated Setup (Recommended)

1. **Clone this repository:**
   ```bash
   git clone https://github.com/yourusername/raspberry-pi-hotspot.git
   cd raspberry-pi-hotspot
   ```

2. **Run the setup script:**
   ```bash
   sudo chmod +x setup_hotspot.sh
   sudo ./setup_hotspot.sh
   ```

3. **Connect to your hotspot:**
   - SSID: `MyHotspot`
   - Password: `MySecurePassword123`
   - IP Range: `192.168.4.2` - `192.168.4.20`

### Option 2: Manual Setup

Follow the detailed step-by-step guide in the [blog post](BLOG_POST.md) for manual configuration.

## ⚙️ Configuration

### Customizing the Hotspot

Edit the configuration variables in `setup_hotspot.sh`:

```bash
SSID="MyHotspot"                    # Your WiFi network name
PASSWORD="MySecurePassword123"       # Your WiFi password
INTERFACE="wlan0"                   # WiFi interface
IP_ADDRESS="192.168.4.1"           # Hotspot IP address
DHCP_RANGE_START="192.168.4.2"     # DHCP start range
DHCP_RANGE_END="192.168.4.20"      # DHCP end range
CHANNEL="7"                         # WiFi channel
```

### Security Settings

- **WPA2 Encryption**: Default security protocol
- **MAC Address Filtering**: Available for additional security
- **Custom DNS**: Configured to use Google DNS (8.8.8.8, 8.8.4.4)

## 📊 Monitoring

### Check Connected Devices
```bash
sudo arp -a
```

### View DHCP Leases
```bash
sudo cat /var/lib/misc/dnsmasq.leases
```

### Monitor Logs
```bash
# hostapd logs
sudo journalctl -u hostapd -f

# dnsmasq logs
sudo journalctl -u dnsmasq -f
```

### Check Service Status
```bash
sudo systemctl status hostapd
sudo systemctl status dnsmasq
```

## 🔧 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| Hotspot not visible | Check `sudo systemctl status hostapd` |
| No internet access | Verify IP forwarding: `cat /proc/sys/net/ipv4/ip_forward` |
| DHCP not working | Check `sudo systemctl status dnsmasq` |
| Connection drops | Monitor logs: `sudo journalctl -u hostapd -f` |

### Debug Commands

```bash
# Check WiFi interface
iwconfig wlan0

# Test DHCP
sudo dnsmasq --test

# Check iptables rules
sudo iptables -t nat -L

# Verify network configuration
ip addr show wlan0
```

## 🔒 Security Considerations

1. **Change Default Passwords**: Always modify the default SSID and password
2. **Regular Updates**: Keep your system updated
3. **Monitor Usage**: Regularly check connected devices
4. **Firewall Rules**: Consider additional iptables rules for security
5. **MAC Filtering**: Enable for restricted access

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## �� Acknowledgments

- [hostapd](https://w1.fi/hostapd/) - WiFi access point daemon
- [dnsmasq](http://www.thekelleys.org.uk/dnsmasq/doc.html) - DHCP and DNS server
- [Raspberry Pi Foundation](https://www.raspberrypi.org/) - Hardware platform

