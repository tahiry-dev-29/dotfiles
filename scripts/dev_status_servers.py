#!/usr/bin/env python3
"""
Development Server discovery adapter for dev-status TUI.
Identifies active application servers (NestJS, Angular, Vite, Next.js, FastAPI, etc.)
Distinguishes application servers from generic system infrastructure services.
Detects active dev servers dynamically on ANY port (including custom/random ports like 37403, 3001, etc.)
and inspects cmdline and package.json to accurately name the dev server.
"""
import subprocess
import os
import re
from typing import List, Dict, Any, Optional
from dev_status_process import validate_pid, terminate_process_safely, validate_port, get_pid_resources
from dev_status_ports import get_project_for_pid, inspect_package_json, detect_real_dev_service

DEV_PORTS_MAP = [
    3000, 3001, 3002, 4200, 5173, 5174, 5555, 8000, 8080
]

def detect_framework(comm: str, cmdline: str, project_dir: str = "N/A") -> str:
    """Accurately detect framework dynamically without static name collisions."""
    detected = detect_real_dev_service(comm, cmdline, project_dir)
    if detected:
        return detected

    c = (comm + " " + cmdline).lower()
    if "bun" in c:
        return "Bun Dev"
    if "node" in c:
        return "Node"
    if "python" in c:
        return "Python"
    return "Custom App"

def discover_dev_servers() -> List[Dict[str, Any]]:
    """
    Returns normalized active development servers:
    [{
        'project': 'backend',
        'framework': 'Next.js' | 'NestJS' | 'React' | 'Angular' | ...,
        'command': 'next dev',
        'pid': 18452,
        'port': 3000,
        'directory': '~/projects/backend',
        'state': 'running'
    }]
    """
    servers: List[Dict[str, Any]] = []
    seen_ports = set()
    seen_pids = set()

    # 1. Probe all listening ports via ss to detect dynamic and random dev server ports
    try:
        ss_res = subprocess.run(["ss", "-tulnp"], capture_output=True, text=True)
        if ss_res.returncode == 0:
            for line in ss_res.stdout.splitlines()[1:]:
                parts = line.split()
                if len(parts) >= 5:
                    local_addr = parts[4]
                    port_str = local_addr.rsplit(":", 1)[-1]
                    p_val = validate_port(port_str)
                    if not p_val or p_val in seen_ports:
                        continue

                    # Ignore infrastructure ports (Postgres, Redis, MySQL, Mongo, Docker, DNS, SSH, etc.)
                    if p_val in (5432, 6379, 3306, 27017, 22, 53, 68):
                        continue

                    pid = None
                    proc = ""
                    if len(parts) >= 6:
                        proc_info = " ".join(parts[5:])
                        m_pid = re.search(r'pid=(\d+)', proc_info)
                        if m_pid:
                            pid = validate_pid(m_pid.group(1))
                        m_name = re.search(r'\(\("([^"]+)"', proc_info)
                        if m_name:
                            proc = m_name.group(1)

                    if not pid:
                        # Try fuser for this port
                        try:
                            f_res = subprocess.run(["fuser", f"{p_val}/tcp"], capture_output=True, text=True)
                            out = (f_res.stdout + " " + f_res.stderr).strip()
                            f_pids = re.findall(r'\b\d+\b', out)
                            v_pids = [int(x) for x in f_pids if int(x) != p_val]
                            if v_pids:
                                pid = v_pids[0]
                        except Exception:
                            pass

                    if pid and pid not in seen_pids:
                        comm = proc
                        cmdline = ""
                        try:
                            ps_res = subprocess.run(["ps", "-p", str(pid), "-o", "comm=,args="], capture_output=True, text=True)
                            if ps_res.returncode == 0 and ps_res.stdout.strip():
                                ps_parts = ps_res.stdout.strip().split(None, 1)
                                if ps_parts:
                                    comm = ps_parts[0]
                                    cmdline = ps_parts[1] if len(ps_parts) > 1 else comm
                        except Exception:
                            pass

                        combined = (comm + " " + cmdline).lower()
                        # Check if process is a dev process (node, bun, python, next, angular, vite, nest, etc.)
                        is_dev = any(k in combined for k in [
                            "node", "bun", "angular", "ng serve", "@angular", "vite", "next",
                            "nuxt", "nest", "@nestjs", "react", "vue", "uvicorn", "fastapi",
                            "manage.py", "prisma studio", "pnpm start", "npm run", "bun run"
                        ])

                        if is_dev:
                            seen_ports.add(p_val)
                            seen_pids.add(pid)
                            cwd = get_project_for_pid(pid, cmdline)
                            framework = detect_framework(comm, cmdline, cwd)
                            project_name = os.path.basename(cwd) if cwd and cwd != "N/A" else f"port-{p_val}"
                            res_info = get_pid_resources(pid)

                            servers.append({
                                "project": project_name,
                                "framework": framework,
                                "command": (cmdline[:40] + "...") if len(cmdline) > 40 else (cmdline or f"port {p_val}"),
                                "pid": pid,
                                "port": p_val,
                                "directory": cwd,
                                "state": "running",
                                "rss_mb": res_info["rss_mb"],
                                "cpu": res_info["cpu"],
                            })
    except Exception:
        pass

    # 2. Probe well-known dev ports via fuser if not already found
    for port in DEV_PORTS_MAP:
        if port in seen_ports:
            continue
        try:
            res = subprocess.run(["fuser", f"{port}/tcp"], capture_output=True, text=True)
            out = (res.stdout + " " + res.stderr).strip()
            pids = re.findall(r'\b\d+\b', out)
            valid_pids = [int(x) for x in pids if int(x) != port]

            if valid_pids:
                pid = valid_pids[0]
                if pid in seen_pids:
                    continue
                seen_ports.add(port)
                seen_pids.add(pid)

                comm = ""
                cmdline = ""
                ps_res = subprocess.run(["ps", "-p", str(pid), "-o", "comm=,args="], capture_output=True, text=True)
                if ps_res.returncode == 0 and ps_res.stdout.strip():
                    parts = ps_res.stdout.strip().split(None, 1)
                    comm = parts[0] if parts else ""
                    cmdline = parts[1] if len(parts) > 1 else comm

                cwd = get_project_for_pid(pid, cmdline)
                framework = detect_framework(comm, cmdline, cwd)
                project_name = os.path.basename(cwd) if cwd and cwd != "N/A" else f"port-{port}"
                res_info = get_pid_resources(pid)

                servers.append({
                    "project": project_name,
                    "framework": framework,
                    "command": (cmdline[:40] + "...") if len(cmdline) > 40 else (cmdline or f"port {port}"),
                    "pid": pid,
                    "port": port,
                    "directory": cwd,
                    "state": "running",
                    "rss_mb": res_info["rss_mb"],
                    "cpu": res_info["cpu"],
                })
        except Exception:
            pass

    # 3. Check processes running dev commands with dynamic ports specified in args
    try:
        ps_all = subprocess.run(["ps", "-eo", "pid,comm,args"], capture_output=True, text=True)
        if ps_all.returncode == 0:
            for line in ps_all.stdout.splitlines()[1:]:
                parts = line.strip().split(None, 2)
                if len(parts) >= 3:
                    p_str, comm, args = parts[0], parts[1], parts[2]
                    pid_val = validate_pid(p_str)
                    if not pid_val or pid_val in seen_pids:
                        continue

                    args_lower = args.lower()
                    if any(ig in args_lower for ig in ["orca", "brave", "chrome", "grep", "codex", "chatgpt"]):
                        continue

                    is_candidate = False
                    detected_port = None

                    # Angular detection (e.g. ng serve --port 37403)
                    if "ng serve" in args_lower or "@angular/cli" in args_lower:
                        is_candidate = True
                        m_port = re.search(r'--port(?:=|\s+)(\d+)', args)
                        if m_port:
                            detected_port = int(m_port.group(1))

                    # Next.js dev server detection (e.g. next dev -p 3001)
                    elif "next dev" in args_lower or "next-server" in comm.lower():
                        is_candidate = True
                        m_port = re.search(r'-p(?:=|\s+)(\d+)', args)
                        if m_port:
                            detected_port = int(m_port.group(1))

                    # Vite dev server detection (e.g. vite --port 5174)
                    elif "vite" in args_lower and ("dev" in args_lower or "serve" in args_lower or "bin/vite" in args_lower):
                        is_candidate = True
                        m_port = re.search(r'--port(?:=|\s+)(\d+)', args)
                        if m_port:
                            detected_port = int(m_port.group(1))

                    # Prisma studio detection
                    elif "prisma studio" in args_lower:
                        is_candidate = True
                        detected_port = 5555

                    if is_candidate and detected_port:
                        seen_pids.add(pid_val)
                        seen_ports.add(detected_port)
                        cwd = get_project_for_pid(pid_val, args)
                        framework = detect_framework(comm, args, cwd)
                        project_name = os.path.basename(cwd) if cwd and cwd != "N/A" else "dev-app"
                        res_info = get_pid_resources(pid_val)

                        servers.append({
                            "project": project_name,
                            "framework": framework,
                            "command": (args[:40] + "...") if len(args) > 40 else args,
                            "pid": pid_val,
                            "port": detected_port,
                            "directory": cwd,
                            "state": "running",
                            "rss_mb": res_info["rss_mb"],
                            "cpu": res_info["cpu"],
                        })
    except Exception:
        pass

    servers.sort(key=lambda x: (x["port"] == 0, x["port"]))
    return servers

def terminate_dev_server(server: Dict[str, Any], sudo_password: Optional[str] = None) -> tuple[bool, str]:
    """Terminate development server safely by PID."""
    pid = server.get("pid")
    if not pid:
        return False, f"Server {server.get('project')} is not running (no PID)"

    valid_pid = validate_pid(pid)
    if not valid_pid:
        return False, f"Invalid PID {pid}"

    return terminate_process_safely(valid_pid, sudo_password=sudo_password)
