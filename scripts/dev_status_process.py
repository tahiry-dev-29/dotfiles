#!/usr/bin/env python3
"""
Safe process termination and port validation module.
Reused by ports, services, and dev-server controllers.
"""
import os
import signal
import time
import subprocess
from typing import Tuple, List, Optional

def validate_port(port_val) -> Optional[int]:
    """Validate port as integer within valid port range (1-65535)."""
    try:
        p = int(port_val)
        if 1 <= p <= 65535:
            return p
    except (ValueError, TypeError):
        pass
    return None

def validate_pid(pid_val) -> Optional[int]:
    """Validate PID as positive integer and verify it is not protected (e.g. pid <= 1)."""
    try:
        pid = int(pid_val)
        if pid > 1:
            return pid
    except (ValueError, TypeError):
        pass
    return None

def is_pid_alive(pid: int) -> bool:
    """Check if process is alive without raising exception."""
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True

def terminate_process_safely(pid: int, timeout_sec: float = 1.0, sudo_password: Optional[str] = None) -> Tuple[bool, str]:
    """
    Safely terminates process using graceful SIGTERM first, then SIGKILL if needed.
    Never uses shell eval.
    Supports sudo_password input for elevated processes.
    """
    valid_pid = validate_pid(pid)
    if not valid_pid:
        return False, f"Invalid PID: {pid}"

    if not is_pid_alive(valid_pid):
        return True, f"Process {valid_pid} already stopped"

    try:
        os.kill(valid_pid, signal.SIGTERM)
    except PermissionError:
        # Try sudo kill with stdin password if provided
        cmd = ["sudo", "-S", "kill", "-TERM", str(valid_pid)] if sudo_password else ["sudo", "-n", "kill", "-TERM", str(valid_pid)]
        input_data = (sudo_password + "\n") if sudo_password else None
        res = subprocess.run(cmd, input=input_data, capture_output=True, text=True)
        if res.returncode != 0:
            return False, f"Permission denied terminating PID {valid_pid}"
    except ProcessLookupError:
        return True, f"PID {valid_pid} terminated"
    except Exception as e:
        return False, f"Error sending SIGTERM to {valid_pid}: {e}"

    # Wait briefly for graceful shutdown
    deadline = time.time() + timeout_sec
    while time.time() < deadline:
        if not is_pid_alive(valid_pid):
            return True, f"PID {valid_pid} terminated gracefully"
        time.sleep(0.1)

    # If still alive, proceed to SIGKILL
    try:
        os.kill(valid_pid, signal.SIGKILL)
    except PermissionError:
        cmd = ["sudo", "-S", "kill", "-KILL", str(valid_pid)] if sudo_password else ["sudo", "-n", "kill", "-KILL", str(valid_pid)]
        input_data = (sudo_password + "\n") if sudo_password else None
        subprocess.run(cmd, input=input_data, capture_output=True, text=True)
    except ProcessLookupError:
        return True, f"PID {valid_pid} terminated"
    except Exception as e:
        return False, f"Error sending SIGKILL to {valid_pid}: {e}"

    time.sleep(0.2)
    if not is_pid_alive(valid_pid):
        return True, f"PID {valid_pid} killed"
    return False, f"Failed to terminate PID {valid_pid}"
