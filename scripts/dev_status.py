#!/usr/bin/env python3
"""
Main CLI entry point for dev-status.
Supports direct interactive dashboard launch or specific tab launch:
  dev-status [--tab ports|services|serve-dev]
"""
import sys
import os
import argparse
import curses

# Ensure scripts dir is in sys.path
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from dev_status_tui import DevStatusApp, TABS

def main():
    parser = argparse.ArgumentParser(description="Modern Developer Dashboard TUI")
    parser.add_argument("--tab", choices=["ports", "services", "serve-dev"], help="Open directly to specified tab")
    args = parser.parse_args()

    init_tab = 0
    if args.tab:
        t_lower = args.tab.lower()
        if t_lower == "ports":
            init_tab = 0
        elif t_lower == "services":
            init_tab = 1
        elif t_lower == "serve-dev":
            init_tab = 2

    # Check terminal interactive capability
    if not sys.stdin.isatty():
        # Fallback to non-interactive structured overview
        from dev_status_ports import discover_ports
        from dev_status_services import discover_services
        from dev_status_servers import discover_dev_servers

        print("=== PORTS ===")
        for p in discover_ports():
            print(f"  {p['port']}\t{p['service']}\t{p['protocol']}\t{p['address']}")
        print("\n=== SERVICES ===")
        for s in discover_services():
            print(f"  {s['name']}\t{s['state']}\t{s['provider']}\t{s['port']}")
        print("\n=== SERVE-DEV ===")
        for d in discover_dev_servers():
            print(f"  {d['project']}\t{d['framework']}\t:{d['port']}\t{d['state']}")
        return 0

    def curses_runner(stdscr):
        app = DevStatusApp(stdscr)
        app.current_tab = init_tab
        app.run()

    try:
        curses.wrapper(curses_runner)
    except KeyboardInterrupt:
        pass
    return 0

if __name__ == "__main__":
    sys.exit(main())
