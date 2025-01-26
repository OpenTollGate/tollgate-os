I'll help you modify the init.d service files to use the new `tollgate-` prefixed commands. Here's how each service file should be updated:

```bash
# crowsnest
#!/bin/sh /etc/rc.common

START=99
STOP=15

EXTRA_COMMANDS="status"
EXTRA_HELP="        status          Check service status"

start() {
    echo "Starting TollGate crowsnest" > /tmp/crowsnest.log 2>&1
    tollgate-crowsnest >> /tmp/crowsnest.log 2>&1 &
    echo "PID: $!" >> /tmp/crowsnest.log 2>&1
}

stop() {
    echo "Stopping TollGate crowsnest"
    killall tollgate-crowsnest
}

status() {
    if pgrep -f "tollgate-crowsnest" >/dev/null; then
        echo "TollGate crowsnest is running"
        return 0
    else
        echo "TollGate crowsnest is not running"
        return 1
    fi
}
```

```bash
# merchant
#!/bin/sh /etc/rc.common

START=99
STOP=15

EXTRA_COMMANDS="status"
EXTRA_HELP="        status          Check service status"

start() {
    echo "Starting TollGate merchant" > /tmp/merchant.log 2>&1
    tollgate-merchant >> /tmp/merchant.log 2>&1 &
    echo "PID: $!" >> /tmp/merchant.log 2>&1
}

stop() {
    echo "Stopping TollGate merchant"
    killall tollgate-merchant
}

status() {
    if pgrep -f "tollgate-merchant" >/dev/null; then
        echo "TollGate merchant is running"
        return 0
    else
        echo "TollGate merchant is not running"
        return 1
    fi
}
```

```bash
# relay
#!/bin/sh /etc/rc.common

START=99
STOP=15

EXTRA_COMMANDS="status"
EXTRA_HELP="        status          Check service status"

start() {
    echo "Starting TollGate relay" > /tmp/relay.log 2>&1
    tollgate-relay >> /tmp/relay.log 2>&1 &
    echo "PID: $!" >> /tmp/relay.log 2>&1
}

stop() {
    echo "Stopping TollGate relay"
    killall tollgate-relay
}

status() {
    if pgrep -f "tollgate-relay" >/dev/null; then
        echo "TollGate relay is running"
        return 0
    else
        echo "TollGate relay is not running"
        return 1
    fi
}
```

```bash
# valve
#!/bin/sh /etc/rc.common

START=99
STOP=15

EXTRA_COMMANDS="status"
EXTRA_HELP="        status          Check service status"

start() {
    echo "Starting TollGate valve" > /tmp/valve.log 2>&1
    tollgate-valve >> /tmp/valve.log 2>&1 &
    echo "PID: $!" >> /tmp/valve.log 2>&1
}

stop() {
    echo "Stopping TollGate valve"
    killall tollgate-valve
}

status() {
    if pgrep -f "tollgate-valve" >/dev/null; then
        echo "TollGate valve is running"
        return 0
    else
        echo "TollGate valve is not running"
        return 1
    fi
}
```

```bash
# whoami
#!/bin/sh /etc/rc.common

START=99
STOP=15

EXTRA_COMMANDS="status"
EXTRA_HELP="        status          Check service status"

start() {
    echo "Starting TollGate whoami" > /tmp/whoami.log 2>&1
    tollgate-whoami >> /tmp/whoami.log 2>&1 &
    echo "PID: $!" >> /tmp/whoami.log 2>&1
}

stop() {
    echo "Stopping TollGate whoami"
    killall tollgate-whoami
}

status() {
    if pgrep -f "tollgate-whoami" >/dev/null; then
        echo "TollGate whoami is running"
        return 0
    else
        echo "TollGate whoami is not running"
        return 1
    fi
}
```

Key changes made:
1. Changed all command paths from `/root/[command]` to `tollgate-[command]`
2. Updated the pgrep patterns in status functions to match new command names
3. Fixed the redirection operator in the start functions (changed from `/file` to `> /file`)
4. Updated killall commands to use new command names

The travelmate service can remain unchanged since it's not part of the TollGate module commands.