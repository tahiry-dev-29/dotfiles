#!/usr/bin/env python3
"""
Safe process termination and port validation module.
Reused by ports, services, and dev-server controllers.
"""
import os
import signal
import time
import subprocess
from typing import Tuple, List, Optional, Dict, Any

# Cached system clock ticks per second (for CPU% calculation)
_CLK_TCK = os.sysconf("SC_CLK_TCK") if hasattr(os, "sysconf") else 100


def get_pid_resources(pid: Optional[int]) -> Dict[str, Any]:
    """
    Read CPU % and RSS memory (in MB) for a given PID directly from /proc.
    Returns dict: {'cpu': float | None, 'rss_mb': float | None}

    CPU % is computed as a snapshot against process lifetime (cumulative), which
    gives a "total average" rather than instantaneous — suitable for a TUI list view.
    For a more responsive instantaneous reading, two samples 0.3s apart are taken.
    """
    result: Dict[str, Any] = {"cpu": None, "rss_mb": None}

    if not pid:
        return result

    def read_stat(p: int):
        try:
            with open(f"/proc/{p}/stat", "r") as f:
                return f.read().split()
        except Exception:
            return None

    def read_rss_kb(p: int) -> Optional[float]:
        """Read VmRSS from /proc/{p}/status (kB)."""
        try:
            with open(f"/proc/{p}/status", "r") as f:
                for line in f:
                    if line.startswith("VmRSS:"):
                        parts = line.split()
                        if len(parts) >= 2:
                            return float(parts[1])
        except Exception:
            pass
        return None

    # RSS
    rss_kb = read_rss_kb(pid)
    if rss_kb is not None:
        result["rss_mb"] = round(rss_kb / 1024.0, 1)

    # CPU% — two-sample approach (delta over ~0.3 s)
    try:
        stat1 = read_stat(pid)
        if stat1 and len(stat1) > 14:
            utime1 = int(stat1[13])
            stime1 = int(stat1[14])
            t1 = time.time()
            time.sleep(0.3)
            stat2 = read_stat(pid)
            t2 = time.time()
            if stat2 and len(stat2) > 14:
                utime2 = int(stat2[13])
                stime2 = int(stat2[14])
                delta_ticks = (utime2 + stime2) - (utime1 + stime1)
                delta_sec = t2 - t1
                if delta_sec > 0:
                    cpu_pct = (delta_ticks / _CLK_TCK) / delta_sec * 100.0
                    result["cpu"] = round(cpu_pct, 1)
    except Exception:
        pass

    return result

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
