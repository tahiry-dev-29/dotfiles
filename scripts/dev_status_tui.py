#!/usr/bin/env python3
"""
Dashboard layout and curses rendering engine for dev-status TUI.
Provides modern, Nx-styled responsive terminal layout with 3 tabs:
PORTS, SERVICES, SERVE-DEV.
Supports multi-select, details modal, recent logs, fuzzy search,
and password input modal ('p' key or automatic elevation prompt).
"""
import curses
import time
import subprocess
from typing import List, Dict, Any, Optional, Set
from dev_status_ports import discover_ports
from dev_status_services import discover_services, stop_service_safely, start_service_safely
from dev_status_servers import discover_dev_servers, terminate_dev_server
from dev_status_process import terminate_process_safely, validate_pid

TABS = ["PORTS", "SERVICES", "SERVE-DEV"]

class DevStatusApp:
    def __init__(self, stdscr):
        self.stdscr = stdscr
        self.current_tab = 0 # 0: PORTS, 1: SERVICES, 2: SERVE-DEV
        self.cursor_pos = [0, 0, 0] # Cursor index per tab
        self.selected_indices: List[Set[int]] = [set(), set(), set()]
        self.search_queries = ["", "", ""]
        self.search_mode = False
        
        # Sudo password session cache (in-memory only)
        self.sudo_password: Optional[str] = None
        
        # Data caches
        self.ports_data: List[Dict[str, Any]] = []
        self.services_data: List[Dict[str, Any]] = []
        self.servers_data: List[Dict[str, Any]] = []
        
        # Log preview cache: key -> list of string lines
        self.log_cache: Dict[str, List[str]] = {}
        self.last_log_fetch: Dict[str, float] = {}

        self.status_message = "Ready"
        self.status_time = time.time()
        
        self.init_colors()
        self.refresh_data()

    def init_colors(self):
        curses.start_color()
        curses.use_default_colors()
        curses.init_pair(1, curses.COLOR_CYAN, -1)     # Header / Active Tab
        curses.init_pair(2, curses.COLOR_GREEN, -1)    # Running / Success
        curses.init_pair(3, curses.COLOR_RED, -1)      # Stopped / Error
        curses.init_pair(4, curses.COLOR_YELLOW, -1)   # Warning / Port
        curses.init_pair(5, curses.COLOR_WHITE, curses.COLOR_BLUE) # Selection / Focused Bar
        curses.init_pair(6, curses.COLOR_MAGENTA, -1)  # Framework / Tags
        curses.init_pair(7, curses.COLOR_BLACK, curses.COLOR_CYAN) # Inverted Highlight

    def set_status(self, msg: str):
        self.status_message = msg
        self.status_time = time.time()

    def refresh_data(self):
        self.ports_data = discover_ports()
        self.services_data = discover_services()
        self.servers_data = discover_dev_servers()
        self.log_cache.clear()
        self.last_log_fetch.clear()

        # Bound cursors
        for tab_idx, data in enumerate([self.ports_data, self.services_data, self.servers_data]):
            if self.cursor_pos[tab_idx] >= len(data):
                self.cursor_pos[tab_idx] = max(0, len(data) - 1)
        self.set_status("Data refreshed")

    def get_filtered_items(self, tab_idx: int) -> List[tuple[int, Dict[str, Any]]]:
        """Returns list of (original_idx, item) matching current search query."""
        data = [self.ports_data, self.services_data, self.servers_data][tab_idx]
        q = self.search_queries[tab_idx].lower().strip()
        if not q:
            return list(enumerate(data))

        filtered = []
        for idx, item in enumerate(data):
            if tab_idx == 0: # Ports
                match = (q in str(item["port"]) or
                         q in item["process"].lower() or
                         q in item["service"].lower() or
                         q in str(item.get("pid") or "") or
                         q in item.get("project", "").lower())
            elif tab_idx == 1: # Services
                match = (q in item["name"].lower() or
                         q in item["provider"].lower() or
                         q in item["state"].lower())
            else: # Serve-Dev
                match = (q in item["project"].lower() or
                         q in item["framework"].lower() or
                         q in str(item["port"]) or
                         q in item["command"].lower())
            if match:
                filtered.append((idx, item))
        return filtered

    @staticmethod
    def _fmt_res(item: Dict[str, Any]) -> str:
        """Format CPU% and RSS into a compact string for inline display.
        Examples: '1.2% 45M'  '0.0% 1.2G'  '--  --'
        """
        cpu = item.get("cpu")
        rss_mb = item.get("rss_mb")

        cpu_str = f"{cpu:.1f}%" if cpu is not None else "--"
        if rss_mb is not None:
            if rss_mb >= 1024:
                rss_str = f"{rss_mb / 1024:.1f}G"
            else:
                rss_str = f"{rss_mb:.0f}M"
        else:
            rss_str = "--"

        return f"{cpu_str} {rss_str}"

    def get_recent_logs(self, item: Dict[str, Any]) -> List[str]:
        """Fetch compact recent output/logs safely without blocking."""
        key = ""
        now = time.time()
        if self.current_tab == 1: # Services
            provider = item.get("provider")
            if provider == "systemd" and item.get("unit"):
                key = f"journal:{item['unit']}"
                if key in self.log_cache and (now - self.last_log_fetch.get(key, 0) < 5):
                    return self.log_cache[key]
                try:
                    res = subprocess.run(
                        ["journalctl", "-u", item["unit"], "-n", "8", "--no-pager", "-q"],
                        capture_output=True, text=True, timeout=1.0
                    )
                    lines = [ln.strip() for ln in res.stdout.splitlines() if ln.strip()][-6:]
                    self.log_cache[key] = lines or ["(No recent journal logs)"]
                    self.last_log_fetch[key] = now
                    return self.log_cache[key]
                except Exception:
                    return ["(Log unavailable)"]

            elif provider == "docker" and item.get("container_id"):
                key = f"docker:{item['container_id']}"
                if key in self.log_cache and (now - self.last_log_fetch.get(key, 0) < 5):
                    return self.log_cache[key]
                try:
                    res = subprocess.run(
                        ["docker", "logs", "--tail", "8", item["container_id"]],
                        capture_output=True, text=True, timeout=1.0
                    )
                    out = res.stdout + res.stderr
                    lines = [ln.strip() for ln in out.splitlines() if ln.strip()][-6:]
                    self.log_cache[key] = lines or ["(No container logs)"]
                    self.last_log_fetch[key] = now
                    return self.log_cache[key]
                except Exception:
                    return ["(Log unavailable)"]

        elif self.current_tab in (0, 2): # Ports or Dev servers
            pid = item.get("pid")
            if pid:
                key = f"pid:{pid}"
                if key in self.log_cache:
                    return self.log_cache[key]
                try:
                    res = subprocess.run(
                        ["ps", "-p", str(pid), "-o", "%cpu,%mem,etime,args="],
                        capture_output=True, text=True, timeout=1.0
                    )
                    lines = [ln.strip() for ln in res.stdout.splitlines() if ln.strip()]
                    self.log_cache[key] = lines or ["(Process active)"]
                    self.last_log_fetch[key] = now
                    return self.log_cache[key]
                except Exception:
                    pass
        return []

    def draw_box(self, y: int, x: int, h: int, w: int, title: str = ""):
        if h < 2 or w < 2:
            return
        try:
            self.stdscr.addstr(y, x, "┌" + "─" * (w - 2) + "┐")
            for i in range(1, h - 1):
                self.stdscr.addstr(y + i, x, "│" + " " * (w - 2) + "│")
            self.stdscr.addstr(y + h - 1, x, "└" + "─" * (w - 2) + "┘")
            if title and len(title) < w - 4:
                self.stdscr.addstr(y, x + 2, f" {title} ", curses.A_BOLD | curses.color_pair(1))
        except curses.error:
            pass

    def render(self):
        self.stdscr.erase()
        max_y, max_x = self.stdscr.getmaxyx()
        if max_y < 12 or max_x < 40:
            try:
                self.stdscr.addstr(0, 0, "Terminal window too small.", curses.color_pair(3))
            except curses.error:
                pass
            self.stdscr.refresh()
            return

        # ── 1. Top Header ──────────────────────────────────────────────
        total_running = sum(1 for s in self.services_data if s["state"] == "running") + \
                        sum(1 for s in self.servers_data if s["state"] == "running")
        total_stopped = sum(1 for s in self.services_data if s["state"] == "stopped") + \
                        sum(1 for s in self.servers_data if s["state"] == "stopped")
        total_ports = len(self.ports_data)

        summary_str = f"● {total_running} running · ○ {total_stopped} stopped · {total_ports} ports"
        
        try:
            self.stdscr.addstr(0, 2, "DEV STATUS", curses.A_BOLD | curses.color_pair(1))
            if max_x > len(summary_str) + 20:
                self.stdscr.addstr(0, max_x - len(summary_str) - 3, summary_str, curses.color_pair(2))
        except curses.error:
            pass

        # ── 2. Tabs Row ────────────────────────────────────────────────
        tab_y = 2
        curr_x = 2
        for i, tab_name in enumerate(TABS):
            is_active = (i == self.current_tab)
            sel_count = len(self.selected_indices[i])
            count_badge = f" ({sel_count})" if sel_count > 0 else ""
            tab_str = f" [ {i+1} {tab_name}{count_badge} ] "
            attr = curses.A_BOLD | curses.color_pair(7 if is_active else 1)
            try:
                self.stdscr.addstr(tab_y, curr_x, tab_str, attr)
            except curses.error:
                pass
            curr_x += len(tab_str) + 1

        # ── 3. Main Split Area: Left List, Right Details ───────────────
        content_y = 4
        footer_height = 2
        content_h = max_y - content_y - footer_height

        is_wide = max_x >= 84
        if is_wide:
            list_w = max(34, int(max_x * 0.46))
            details_w = max_x - list_w - 4
            details_x = list_w + 3
        else:
            list_w = max_x - 4
            details_w = 0
            details_x = 0

        # Draw List Container
        tab_title = f"{TABS[self.current_tab]} LIST"
        if self.search_queries[self.current_tab]:
            tab_title += f" [Filter: {self.search_queries[self.current_tab]}]"
        self.draw_box(content_y, 1, content_h, list_w + 2, tab_title)

        # Draw Details Container if Wide
        if is_wide and details_w > 10:
            self.draw_box(content_y, details_x, content_h, details_w, "DETAILS & RECENT OUTPUT")

        # ── 4. Render Active Tab Items ─────────────────────────────────
        filtered = self.get_filtered_items(self.current_tab)
        current_cursor = self.cursor_pos[self.current_tab]
        if current_cursor >= len(filtered):
            current_cursor = max(0, len(filtered) - 1)
            self.cursor_pos[self.current_tab] = current_cursor

        selected_set = self.selected_indices[self.current_tab]
        
        visible_lines = content_h - 2
        start_idx = max(0, current_cursor - visible_lines // 2)
        end_idx = min(len(filtered), start_idx + visible_lines)

        focused_item = None

        if not filtered:
            msg = " (No active items found)" if self.current_tab == 2 else " (No items)"
            try:
                self.stdscr.addstr(content_y + 2, 4, msg, curses.A_DIM)
            except curses.error:
                pass

        for view_idx, (orig_idx, item) in enumerate(filtered[start_idx:end_idx]):
            row_y = content_y + 1 + view_idx
            is_focused = ((start_idx + view_idx) == current_cursor)
            if is_focused:
                focused_item = item

            is_selected = (orig_idx in selected_set)
            sel_sym = "●" if is_selected else "○"

            # Format Row String depending on tab
            row_str = ""
            if self.current_tab == 0: # PORTS
                p_num = str(item["port"]).ljust(5)
                srv = item["service"][:12].ljust(12)
                row_str = f" {sel_sym} {p_num} {srv}"
            elif self.current_tab == 1: # SERVICES
                state_badge = "running" if item["state"] == "running" else "stopped"
                state_icon = "●" if item["state"] == "running" else "○"
                name_fmt = item["name"][:16].ljust(16)
                row_str = f" {sel_sym} {state_icon} {name_fmt} {state_badge}"
            else: # SERVE-DEV
                st_icon = "●" if item["state"] == "running" else "○"
                proj_fmt = item["project"][:10].ljust(10)
                fw_fmt = item["framework"][:10].ljust(10)
                p_fmt = f":{item['port']}".ljust(6)
                row_str = f" {sel_sym} {st_icon} {proj_fmt} {fw_fmt} {p_fmt}"

            # Resource badge: CPU% RSS  — rendered right-aligned within the box
            res_badge = self._fmt_res(item)
            res_w = len(res_badge) + 1  # right padding

            # Truncate main text + pad, then overlay resource badge at right edge
            max_main = list_w - res_w - 2
            if len(row_str) > max_main:
                row_str = row_str[:max_main - 1] + "…"
            row_str = row_str.ljust(list_w)
            # Embed resource badge at right end of the fixed-width string
            badge_pos = list_w - res_w
            row_str = row_str[:badge_pos] + res_badge + " "

            row_attr = curses.color_pair(5) if is_focused else curses.A_NORMAL
            if not is_focused and is_selected:
                row_attr = curses.A_BOLD | curses.color_pair(4)

            try:
                self.stdscr.addstr(row_y, 2, row_str, row_attr)
                # Highlight resource badge in yellow when not focused/selected
                if not is_focused and not is_selected:
                    badge_x = 2 + badge_pos
                    self.stdscr.addstr(row_y, badge_x, res_badge, curses.color_pair(4) | curses.A_DIM)
            except curses.error:
                pass

        # ── 5. Render Details Panel ────────────────────────────────────
        if is_wide and details_w > 10 and focused_item:
            det_y = content_y + 1
            det_x = details_x + 2
            max_det_lines = content_h - 3
            
            lines_to_draw = []

            if self.current_tab == 0: # PORT DETAILS
                lines_to_draw.append(("PORT DETAILS", curses.A_BOLD | curses.color_pair(1)))
                lines_to_draw.append(("", curses.A_NORMAL))
                lines_to_draw.append((f"Port        : {focused_item['port']}", curses.color_pair(4) | curses.A_BOLD))
                lines_to_draw.append((f"Service     : {focused_item['service']}", curses.A_NORMAL))
                lines_to_draw.append((f"Process     : {focused_item['process']}", curses.A_NORMAL))
                lines_to_draw.append((f"PID         : {focused_item.get('pid') or 'N/A'}", curses.A_NORMAL))
                lines_to_draw.append((f"Address     : {focused_item['address']}", curses.A_NORMAL))
                lines_to_draw.append((f"Protocol    : {focused_item['protocol']}", curses.A_NORMAL))
                lines_to_draw.append((f"State       : {focused_item['state']}", curses.color_pair(2) if focused_item['state'] == 'LISTEN' else curses.A_NORMAL))
                lines_to_draw.append((f"Project     : {focused_item['project']}", curses.A_NORMAL))
                lines_to_draw.append(("", curses.A_NORMAL))
                lines_to_draw.append(("── Resources ──", curses.A_DIM | curses.color_pair(1)))
                cpu_val = focused_item.get("cpu")
                rss_val = focused_item.get("rss_mb")
                cpu_disp = f"{cpu_val:.1f}%" if cpu_val is not None else "N/A"
                rss_disp = (f"{rss_val / 1024:.2f} GB" if rss_val and rss_val >= 1024 else f"{rss_val:.1f} MB") if rss_val is not None else "N/A"
                lines_to_draw.append((f"CPU         : {cpu_disp}", curses.color_pair(2) | curses.A_BOLD))
                lines_to_draw.append((f"RSS Memory  : {rss_disp}", curses.color_pair(4) | curses.A_BOLD))

            elif self.current_tab == 1: # SERVICE DETAILS
                lines_to_draw.append(("SERVICE DETAILS", curses.A_BOLD | curses.color_pair(1)))
                lines_to_draw.append(("", curses.A_NORMAL))
                lines_to_draw.append((f"Name        : {focused_item['name']}", curses.A_BOLD))
                lines_to_draw.append((f"Provider    : {focused_item['provider']}", curses.color_pair(6)))
                st_color = curses.color_pair(2) if focused_item['state'] == 'running' else curses.color_pair(3)
                lines_to_draw.append((f"State       : {focused_item['state']}", st_color | curses.A_BOLD))
                lines_to_draw.append((f"Port        : {focused_item['port'] or 'None'}", curses.A_NORMAL))
                lines_to_draw.append((f"PID         : {focused_item.get('pid') or 'N/A'}", curses.A_NORMAL))
                lines_to_draw.append((f"Uptime      : {focused_item.get('uptime', 'N/A')}", curses.A_NORMAL))
                lines_to_draw.append(("", curses.A_NORMAL))
                lines_to_draw.append(("── Resources ──", curses.A_DIM | curses.color_pair(1)))
                cpu_val = focused_item.get("cpu")
                rss_val = focused_item.get("rss_mb")
                cpu_disp = f"{cpu_val:.1f}%" if cpu_val is not None else "N/A"
                rss_disp = (f"{rss_val / 1024:.2f} GB" if rss_val and rss_val >= 1024 else f"{rss_val:.1f} MB") if rss_val is not None else "N/A"
                lines_to_draw.append((f"CPU         : {cpu_disp}", curses.color_pair(2) | curses.A_BOLD))
                lines_to_draw.append((f"RSS Memory  : {rss_disp}", curses.color_pair(4) | curses.A_BOLD))

            else: # SERVE-DEV DETAILS
                lines_to_draw.append(("DEVELOPMENT SERVER", curses.A_BOLD | curses.color_pair(1)))
                lines_to_draw.append(("", curses.A_NORMAL))
                lines_to_draw.append((f"Project     : {focused_item['project']}", curses.A_BOLD))
                lines_to_draw.append((f"Framework   : {focused_item['framework']}", curses.color_pair(6)))
                st_color = curses.color_pair(2) if focused_item['state'] == 'running' else curses.color_pair(3)
                lines_to_draw.append((f"State       : {focused_item['state']}", st_color | curses.A_BOLD))
                lines_to_draw.append((f"Port        : {focused_item['port']}", curses.color_pair(4)))
                lines_to_draw.append((f"PID         : {focused_item.get('pid') or 'N/A'}", curses.A_NORMAL))
                lines_to_draw.append((f"Directory   : {focused_item.get('directory', 'N/A')}", curses.A_NORMAL))
                lines_to_draw.append((f"Command     : {focused_item.get('command', 'N/A')}", curses.A_NORMAL))
                lines_to_draw.append(("", curses.A_NORMAL))
                lines_to_draw.append(("── Resources ──", curses.A_DIM | curses.color_pair(1)))
                cpu_val = focused_item.get("cpu")
                rss_val = focused_item.get("rss_mb")
                cpu_disp = f"{cpu_val:.1f}%" if cpu_val is not None else "N/A"
                rss_disp = (f"{rss_val / 1024:.2f} GB" if rss_val and rss_val >= 1024 else f"{rss_val:.1f} MB") if rss_val is not None else "N/A"
                lines_to_draw.append((f"CPU         : {cpu_disp}", curses.color_pair(2) | curses.A_BOLD))
                lines_to_draw.append((f"RSS Memory  : {rss_disp}", curses.color_pair(4) | curses.A_BOLD))


            # Add recent output / logs
            recent_logs = self.get_recent_logs(focused_item)
            if recent_logs:
                lines_to_draw.append(("", curses.A_NORMAL))
                lines_to_draw.append(("RECENT OUTPUT / LOGS", curses.A_BOLD | curses.color_pair(1)))
                for l in recent_logs:
                    lines_to_draw.append((f"  {l}", curses.A_DIM))

            # Draw lines safely without overrunning panel width
            max_line_len = max(1, details_w - 4)
            for idx, (text, attr) in enumerate(lines_to_draw[:max_det_lines]):
                safe_text = (text[:max_line_len - 1] + "…") if len(text) > max_line_len else text
                safe_text = safe_text.ljust(max_line_len)
                try:
                    self.stdscr.addstr(det_y + idx, det_x, safe_text, attr)
                except curses.error:
                    pass

        # ── 6. Bottom Navigation Footer ────────────────────────────────
        footer_y = max_y - 2
        selected_count = len(selected_set)
        
        action_verb = "Kill" if self.current_tab in (0, 2) else "Stop"
        start_hint = "  s Start" if self.current_tab == 1 else ""
        pwd_badge = " [Sudo: ✓]" if self.sudo_password else ""
        footer_str = f"↑↓ Move  ←→/1-3 Tabs  TAB Select ({selected_count})  k {action_verb}{start_hint}  p Sudo{pwd_badge}  Enter Details  / Search  r Refresh  ? Help  q Quit"
        
        if self.search_mode:
            footer_str = f"FILTER [/]: {self.search_queries[self.current_tab]}█ (Press Enter or Esc to finish)"

        try:
            self.stdscr.addstr(footer_y, 2, footer_str[:max_x - 4], curses.A_DIM | curses.A_BOLD)
            status_line = f"[{self.status_message}]"
            self.stdscr.addstr(footer_y + 1, 2, status_line[:max_x - 4], curses.color_pair(1))
        except curses.error:
            pass

        self.stdscr.refresh()

    def show_password_input_modal(self) -> Optional[str]:
        """
        Interactive password input modal triggered by 'p' key or when sudo elevation is required.
        Safely captures password without echo and returns the password string.
        """
        max_y, max_x = self.stdscr.getmaxyx()
        h = 8
        w = min(54, max_x - 4)
        y = (max_y - h) // 2
        x = (max_x - w) // 2

        win = curses.newwin(h, w, y, x)
        win.keypad(True)
        win.box()
        win.addstr(1, 2, " SUDO PASSWORD AUTHENTICATION ", curses.A_BOLD | curses.color_pair(1))
        win.addstr(2, 4, "Enter password for process/service control:", curses.A_DIM)
        win.addstr(h - 2, 4, "[ Enter: Confirm ]  [ Esc: Cancel ]", curses.A_DIM)

        entered = []
        curses.curs_set(1)

        while True:
            # Draw input field
            inp_str = "*" * len(entered) + "█"
            win.addstr(4, 4, "Password: [" + inp_str.ljust(w - 18) + "]")
            win.refresh()

            try:
                ch = win.getch()
            except curses.error:
                continue

            if ch in (10, 13, curses.KEY_ENTER):
                curses.curs_set(0)
                pwd = "".join(entered)
                # Verify password validity with sudo -k -S true
                test_res = subprocess.run(["sudo", "-k", "-S", "true"], input=(pwd + "\n"), capture_output=True, text=True)
                if test_res.returncode == 0:
                    self.sudo_password = pwd
                    self.set_status("✓ Sudo password saved for this session")
                    return pwd
                else:
                    self.set_status("❌ Incorrect sudo password")
                    return None
            elif ch in (27, ord('\x1b')): # Esc
                curses.curs_set(0)
                self.set_status("Password input cancelled")
                return None
            elif ch in (curses.KEY_BACKSPACE, 127, 8):
                if entered:
                    entered.pop()
            elif 32 <= ch <= 126:
                if len(entered) < 40:
                    entered.append(chr(ch))

    def show_item_details_modal(self, item: Dict[str, Any]):
        """Dedicated modal detail view (ideal for narrow screens or Enter key)."""
        max_y, max_x = self.stdscr.getmaxyx()
        h = min(20, max_y - 2)
        w = min(68, max_x - 4)
        y = (max_y - h) // 2
        x = (max_x - w) // 2

        win = curses.newwin(h, w, y, x)
        win.box()
        title = f" {TABS[self.current_tab]} DETAILS "
        win.addstr(1, 2, title, curses.A_BOLD | curses.color_pair(1))

        # Shared resource formatting
        cpu_val = item.get("cpu")
        rss_val = item.get("rss_mb")
        cpu_disp = f"{cpu_val:.1f}%" if cpu_val is not None else "N/A"
        rss_disp = (f"{rss_val / 1024:.2f} GB" if rss_val and rss_val >= 1024 else f"{rss_val:.1f} MB") if rss_val is not None else "N/A"

        lines = []
        if self.current_tab == 0:
            lines = [
                f"Port        : {item['port']}",
                f"Service     : {item['service']}",
                f"Process     : {item['process']}",
                f"PID         : {item.get('pid') or 'N/A'}",
                f"Address     : {item['address']}",
                f"Protocol    : {item['protocol']}",
                f"State       : {item['state']}",
                f"Project     : {item['project']}",
                f"",
                f"── Resources ──",
                f"CPU         : {cpu_disp}",
                f"RSS Memory  : {rss_disp}",
            ]
        elif self.current_tab == 1:
            lines = [
                f"Name        : {item['name']}",
                f"Provider    : {item['provider']}",
                f"State       : {item['state']}",
                f"Port        : {item['port'] or 'None'}",
                f"PID         : {item.get('pid') or 'N/A'}",
                f"Uptime      : {item.get('uptime', 'N/A')}",
                f"ID          : {item.get('id', 'N/A')}",
                f"",
                f"── Resources ──",
                f"CPU         : {cpu_disp}",
                f"RSS Memory  : {rss_disp}",
            ]
        else:
            lines = [
                f"Project     : {item['project']}",
                f"Framework   : {item['framework']}",
                f"State       : {item['state']}",
                f"Port        : {item['port']}",
                f"PID         : {item.get('pid') or 'N/A'}",
                f"Directory   : {item.get('directory', 'N/A')}",
                f"Command     : {item.get('command', 'N/A')}",
                f"",
                f"── Resources ──",
                f"CPU         : {cpu_disp}",
                f"RSS Memory  : {rss_disp}",
            ]

        for i, l in enumerate(lines):
            if i + 3 < h - 4:
                win.addstr(i + 3, 4, l[:w - 8])

        # Logs in modal
        recent_logs = self.get_recent_logs(item)
        if recent_logs and len(lines) + 5 < h:
            win.addstr(len(lines) + 3, 4, "── Recent Output ──", curses.A_DIM)
            for j, log_line in enumerate(recent_logs[:h - len(lines) - 6]):
                win.addstr(len(lines) + 4 + j, 4, ("  " + log_line)[:w - 8], curses.A_DIM)

        win.addstr(h - 2, 4, "[ Press Enter / Esc to close ]", curses.A_DIM)
        win.refresh()
        win.getch()

    def show_confirmation_dialog(self, title: str, items_summary: List[str], confirm_btn: str) -> bool:
        """
        Modal confirmation dialog for destructive actions.
        Ensures explicit confirmation before any mutation.
        """
        max_y, max_x = self.stdscr.getmaxyx()
        h = min(len(items_summary) + 6, max_y - 4)
        w = min(60, max_x - 4)
        y = (max_y - h) // 2
        x = (max_x - w) // 2

        dlg_win = curses.newwin(h, w, y, x)
        dlg_win.keypad(True)
        dlg_win.box()
        
        try:
            dlg_win.addstr(1, 2, f" {title} ", curses.A_BOLD | curses.color_pair(3))
            for i, line in enumerate(items_summary[:h - 5]):
                dlg_win.addstr(2 + i, 4, ("• " + line)[:w - 8])
            
            prompt = f"[ Enter: {confirm_btn} ]    [ Esc: Cancel ]"
            dlg_win.addstr(h - 2, (w - len(prompt)) // 2, prompt, curses.A_BOLD | curses.color_pair(7))
            dlg_win.refresh()
        except curses.error:
            pass

        while True:
            ch = dlg_win.getch()
            if ch in (10, 13, curses.KEY_ENTER): # Enter confirms
                return True
            elif ch in (27, ord('q'), ord('Q'), ord('n'), ord('N')): # Esc/q cancels
                return False

    def handle_destructive_action(self):
        """Handle 'k' action depending on active tab."""
        selected_set = self.selected_indices[self.current_tab]
        if not selected_set:
            self.set_status("No items selected.")
            return

        filtered = self.get_filtered_items(self.current_tab)
        target_items = []
        for orig_idx, item in filtered:
            if orig_idx in selected_set:
                target_items.append(item)

        if not target_items:
            self.set_status("No items selected.")
            return

        if self.current_tab == 0: # Kill selected ports
            summary = []
            for it in target_items:
                summary.append(f"Port {it['port']} → {it['service']} (PID: {it.get('pid') or 'unknown'})")
            
            confirmed = self.show_confirmation_dialog("Kill Selected Ports?", summary, "Kill Ports")
            if not confirmed:
                self.set_status("Cancelled.")
                return

            freed = 0
            need_pwd = False
            for it in target_items:
                pid = it.get("pid")
                if pid:
                    ok, msg = terminate_process_safely(pid, sudo_password=self.sudo_password)
                    if ok:
                        freed += 1
                    elif "Permission denied" in msg and not self.sudo_password:
                        need_pwd = True

            if need_pwd:
                pwd = self.show_password_input_modal()
                if pwd:
                    for it in target_items:
                        pid = it.get("pid")
                        if pid:
                            ok, _ = terminate_process_safely(pid, sudo_password=pwd)
                            if ok:
                                freed += 1

            self.selected_indices[0].clear()
            self.refresh_data()
            self.set_status(f"✓ {freed}/{len(target_items)} ports freed")

        elif self.current_tab == 1: # Stop selected services
            summary = [f"{it['name']} ({it['provider']})" for it in target_items]
            confirmed = self.show_confirmation_dialog("Stop Selected Services?", summary, "Stop Services")
            if not confirmed:
                self.set_status("Cancelled.")
                return

            stopped = 0
            need_pwd = False
            for it in target_items:
                ok, msg = stop_service_safely(it, sudo_password=self.sudo_password)
                if ok:
                    stopped += 1
                elif "Permission denied" in msg and not self.sudo_password:
                    need_pwd = True

            if need_pwd:
                pwd = self.show_password_input_modal()
                if pwd:
                    for it in target_items:
                        ok, _ = stop_service_safely(it, sudo_password=pwd)
                        if ok:
                            stopped += 1

            self.selected_indices[1].clear()
            self.refresh_data()
            self.set_status(f"✓ {stopped}/{len(target_items)} services stopped")

        elif self.current_tab == 2: # Terminate selected dev servers
            summary = [f"{it['project']} ({it['framework']} :{it['port']})" for it in target_items]
            confirmed = self.show_confirmation_dialog("Kill Development Servers?", summary, "Kill Servers")
            if not confirmed:
                self.set_status("Cancelled.")
                return

            killed = 0
            need_pwd = False
            for it in target_items:
                ok, msg = terminate_dev_server(it, sudo_password=self.sudo_password)
                if ok:
                    killed += 1
                elif "Permission denied" in msg and not self.sudo_password:
                    need_pwd = True

            if need_pwd:
                pwd = self.show_password_input_modal()
                if pwd:
                    for it in target_items:
                        ok, _ = terminate_dev_server(it, sudo_password=pwd)
                        if ok:
                            killed += 1
            self.selected_indices[2].clear()
            self.refresh_data()
            self.set_status(f"✓ {killed}/{len(target_items)} dev servers terminated")

    def handle_start_action(self):
        """Handle 's' key: start selected stopped services (SERVICES tab only)."""
        if self.current_tab != 1:
            self.set_status("Start only available in SERVICES tab.")
            return

        selected_set = self.selected_indices[self.current_tab]
        if not selected_set:
            self.set_status("No items selected. Press TAB to select services to start.")
            return

        filtered = self.get_filtered_items(self.current_tab)
        target_items = [item for orig_idx, item in filtered
                        if orig_idx in selected_set and item.get("state") == "stopped"]

        if not target_items:
            self.set_status("No stopped services selected.")
            return

        summary = [f"{it['name']} ({it['provider']})" for it in target_items]
        confirmed = self.show_confirmation_dialog("Start Selected Services?", summary, "Start Services")
        if not confirmed:
            self.set_status("Cancelled.")
            return

        started = 0
        need_pwd = False
        for it in target_items:
            ok, msg = start_service_safely(it, sudo_password=self.sudo_password)
            if ok:
                started += 1
            elif "Permission denied" in msg and not self.sudo_password:
                need_pwd = True

        if need_pwd:
            pwd = self.show_password_input_modal()
            if pwd:
                for it in target_items:
                    ok, _ = start_service_safely(it, sudo_password=pwd)
                    if ok:
                        started += 1

        self.selected_indices[1].clear()
        self.refresh_data()
        self.set_status(f"✓ {started}/{len(target_items)} services started")

    def show_help_modal(self):
        max_y, max_x = self.stdscr.getmaxyx()
        h = min(20, max_y - 2)
        w = min(58, max_x - 4)
        y = (max_y - h) // 2
        x = (max_x - w) // 2

        win = curses.newwin(h, w, y, x)
        win.box()
        win.addstr(1, 2, " DEV-STATUS SHORTCUTS ", curses.A_BOLD | curses.color_pair(1))
        
        help_lines = [
            ("← / h", "Previous Tab"),
            ("→ / l", "Next Tab"),
            ("1 / 2 / 3", "Direct Tab (Ports, Services, Serve-Dev)"),
            ("↑ / k", "Move cursor up"),
            ("↓ / j", "Move cursor down"),
            ("TAB", "Toggle item selection"),
            ("k", "Kill / Stop selected items (with confirmation)"),
            ("s", "Start selected services (SERVICES tab only)"),
            ("p", "Enter / cache sudo password for session"),
            ("/", "Fuzzy search / filter tab list"),
            ("r", "Refresh status and processes"),
            ("Enter", "View detailed panel modal"),
            ("q / Esc", "Quit dashboard"),
        ]
        for idx, (key, desc) in enumerate(help_lines):
            if idx + 3 < h - 2:
                win.addstr(idx + 3, 4, f"{key.ljust(14)} : {desc}"[:w-6])
        win.addstr(h - 2, 4, "[ Press any key to close ]", curses.A_DIM)
        win.refresh()
        win.getch()

    def run(self):
        self.stdscr.keypad(True)
        curses.curs_set(0)
        self.stdscr.timeout(500) # 500ms timeout for non-blocking loop

        while True:
            self.render()
            try:
                ch = self.stdscr.getch()
            except curses.error:
                continue

            if ch == -1:
                continue

            # Search mode input capture
            if self.search_mode:
                if ch in (10, 13, 27): # Enter or Esc exits search mode
                    self.search_mode = False
                elif ch in (curses.KEY_BACKSPACE, 127, 8):
                    curr = self.search_queries[self.current_tab]
                    if curr:
                        self.search_queries[self.current_tab] = curr[:-1]
                elif 32 <= ch <= 126:
                    self.search_queries[self.current_tab] += chr(ch)
                continue

            # Global Navigation
            if ch in (ord('q'), ord('Q')):
                break
            elif ch in (ord('h'), curses.KEY_LEFT):
                self.current_tab = (self.current_tab - 1) % len(TABS)
            elif ch in (ord('l'), curses.KEY_RIGHT):
                self.current_tab = (self.current_tab + 1) % len(TABS)
            elif ch == ord('1'):
                self.current_tab = 0
            elif ch == ord('2'):
                self.current_tab = 1
            elif ch == ord('3'):
                self.current_tab = 2
            elif ch == curses.KEY_UP:
                if self.cursor_pos[self.current_tab] > 0:
                    self.cursor_pos[self.current_tab] -= 1
            elif ch in (curses.KEY_DOWN, ord('j')):
                filtered_len = len(self.get_filtered_items(self.current_tab))
                if self.cursor_pos[self.current_tab] < filtered_len - 1:
                    self.cursor_pos[self.current_tab] += 1
            elif ch == ord('k'):
                # When items are selected, k executes destructive action
                if len(self.selected_indices[self.current_tab]) > 0:
                    self.handle_destructive_action()
                else:
                    # Move up fallback if no items are selected
                    if self.cursor_pos[self.current_tab] > 0:
                        self.cursor_pos[self.current_tab] -= 1
                    else:
                        self.set_status("No items selected. Press TAB to select.")
            elif ch in (ord('p'), ord('P')):
                # Password input prompt
                self.show_password_input_modal()
            elif ch in (10, 13, curses.KEY_ENTER): # Enter opens details modal
                filtered = self.get_filtered_items(self.current_tab)
                c_idx = self.cursor_pos[self.current_tab]
                if 0 <= c_idx < len(filtered):
                    _, focused_item = filtered[c_idx]
                    self.show_item_details_modal(focused_item)
            elif ch == ord('\t'): # TAB toggles selection
                filtered = self.get_filtered_items(self.current_tab)
                c_idx = self.cursor_pos[self.current_tab]
                if 0 <= c_idx < len(filtered):
                    orig_idx, _ = filtered[c_idx]
                    sel_set = self.selected_indices[self.current_tab]
                    if orig_idx in sel_set:
                        sel_set.remove(orig_idx)
                    else:
                        sel_set.add(orig_idx)
            elif ch == ord('/'): # Start search
                self.search_mode = True
            elif ch in (ord('r'), ord('R')):
                self.refresh_data()
            elif ch in (ord('?'),):
                self.show_help_modal()
            elif ch in (ord('x'), ord('X')):
                self.handle_destructive_action()
            elif ch in (ord('s'), ord('S')):
                self.handle_start_action()
