## Quickstart Guide: Installing TollGate OS (`.bin` Firmware)

This guide explains how to install TollGate OS by flashing a complete firmware image (`.bin`) onto your router. This method provides a fresh, minimal operating system with TollGate pre-installed.

> **WARNING:** This process will completely wipe all data from your router, including any existing operating system, settings, and personal files. Proceed with caution.

### 1. Download and Transfer the Firmware

First, you need to select the correct firmware for your router model and copy it to the device.

1.  Go to the latest release on the TollGate releases page.
2.  Find the TollGate OS `.bin` file that **exactly matches your router model** (e.g., `gl-mt3000.bin`, `glar300m16.bin`).
3.  Copy the firmware to the `/tmp/` directory on your router. Replace `<model>.bin` with the name of the file you downloaded and `<router_ip>` with your router's current IP address.

    ```bash
    scp <model>.bin root@<router_ip>:/tmp/
    ```

### 2. Flash the TollGate OS Firmware

Now, you will use the `sysupgrade` command to install the new operating system.

1.  Connect to your router via SSH:
    ```bash
    ssh root@<router_ip>
    ```

2.  Navigate to the `/tmp` directory and begin the flashing process. The `-n` flag is crucial as it tells the sysupgrade tool **not** to save any current configuration files.
    ```bash
    cd /tmp
    sysupgrade -n <model>.bin
    ```
3.  The router will begin flashing the new firmware and will automatically reboot when it is finished.

> **Important:** After rebooting, the router will have a new, randomly generated IP address. It will broadcast a new open Wi-Fi network with a name like `TollGate-XXXX-2.4GHz`.

### 3. Verify the Installation

After the router reboots with TollGate OS, check that the service is running correctly.

1.  Connect your computer to the new `TollGate-XXXX-...` Wi-Fi network.
2.  Open a terminal and use `curl` to check the TollGate API endpoint. Replace `<new_router_ip>` with the router's new IP.
    ```bash
    curl http://<new_router_ip>:2121
    ```
3.  You should see a JSON output containing the Tollgate price advertisement, which confirms TollGate is running.

### 4. Connect to Upstream Internet

Your TollGate needs an internet connection. Use the LuCi web interface to connect it to another Wi-Fi network.

1.  In your browser, navigate to the LuCi admin panel at `http://<new_router_ip>:8080`.
2.  Go to **Network** -> **Wireless**.
3.  Click **Scan** on one of the wireless radios (e.g., radio0 for 2.4GHz).
4.  Find your upstream Wi-Fi network, click **Join Network**, and enter the password to connect.
5.  To confirm connectivity, SSH into the router and ping an external address:
    ```bash
    ping 1.1.1.1
    ```

### 5. Configure Your Tollgate

The final step is to configure your payout address and pricing.

#### Set Your Payout Address (Crucial!)

To receive your profits, you must set your Lightning Address.

1.  SSH into your router and open the identities configuration file:
    ```bash
    vi /etc/tollgate/identities.json
    ```
2.  Find the `"owner"` identity and **change the `lightning_address`** from the default to your own. This is required to receive payouts. Save the file.

    ```json
    {
      "name": "owner",
      "pubkey": "[on_setup]",
      "lightning_address": "your-ln-address@provider.com"
    }
    ```

#### Set Pricing and Profit Share

You can customize pricing and other settings in the main configuration file.

1.  Open the configuration file:
    ```bash
    vi /etc/tollgate/config.json
    ```
2.  Adjust `step_size` (in milliseconds) and `price_per_step` (in sats) to set your desired rate.
3.  Review the `profit_share` section to see how earnings are split between the `owner` (you) and the `developer`.

### Troubleshooting

*   **Nothing shows up on port `:2121`**:
    Check the Tollgate logs for errors.
    ```bash
    logread | grep tollgate
    ```

*   **Captive portal does not show up**:
    This means the router is likely offline. Follow the steps in section **4. Connect to Upstream Internet** to establish an internet connection.