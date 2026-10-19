#!/usr/bin/env python3
import json, re, shutil, subprocess, time
TITLE = "RusticQ · Power Menu"
ADDRESS = re.compile(r"0x[0-9a-fA-F]{4,16}\Z")

def get_clients():
    result = subprocess.run(["hyprctl","-j","clients"],capture_output=True,text=True,timeout=3)
    if result.returncode != 0: raise RuntimeError(result.stderr[:180])
    data = json.loads(result.stdout)
    return data if isinstance(data,list) else []

def get_active_workspace():
    for cmd in (["hyprctl","-j","activeworkspace"],["hyprctl","-j","monitors"]):
        try:
            result = subprocess.run(cmd,capture_output=True,text=True,timeout=3)
            if result.returncode != 0: continue
            data = json.loads(result.stdout)
            if isinstance(data,dict):
                wid = data.get("id")
                if type(wid) is int and wid > 0: return wid
            if isinstance(data,list):
                for mon in data:
                    if isinstance(mon,dict) and mon.get('focused') is True:
                        ws = mon.get('activeWorkspace',{})
                        wid = ws.get('id') if isinstance(ws,dict) else None
                        if type(wid) is int and wid > 0: return wid
        except Exception:
            pass
    return None

def find_client(clients):
    for c in clients:
        if isinstance(c,dict) and c.get('title') == TITLE and isinstance(c.get('address'),str) and ADDRESS.fullmatch(c['address']):
            return c
    return None

def workspace(client):
    ws = client.get('workspace',{})
    if isinstance(ws,dict):
        v = ws.get('id')
        if type(v) is int and v > 0: return v
    return None

def dispatch_lua(expr):
    result = subprocess.run(['hyprctl','dispatch',expr],capture_output=True,text=True,timeout=3)
    out=(result.stdout+result.stderr).lower()
    return result.returncode==0 and not any(x in out for x in ('error','invalid','failed','unknown'))

def dispatch_legacy(command,arg):
    result = subprocess.run(['hyprctl','dispatch',command,arg],capture_output=True,text=True,timeout=3)
    out=(result.stdout+result.stderr).lower()
    return result.returncode==0 and not any(x in out for x in ('error','invalid','failed','unknown'))

def arrange(client):
    addr = client['address']
    selector = 'address:' + addr
    literal = json.dumps(selector)
    if client.get('floating') is not True:
        dispatch_lua('hl.dsp.window.float({ action = "set", window = ' + literal + ' })') or dispatch_legacy('togglefloating', selector)
    target_ws = get_active_workspace()
    if target_ws is not None and workspace(client) != target_ws:
        moved = dispatch_lua('hl.dsp.window.move({ window = ' + literal + ', workspace = ' + str(target_ws) + ', follow = false })')
        if not moved:
            moved = dispatch_legacy('movetoworkspacesilent', str(target_ws) + ',' + selector)
        if not moved: return False
        time.sleep(.08)
    dispatch_lua('hl.dsp.window.center({ window = ' + literal + ' })') or dispatch_legacy('centerwindow', selector)
    return True

def main():
    if not shutil.which('hyprctl'): return 0
    for _ in range(16):
        try:
            client = find_client(get_clients())
            if client: return 0 if arrange(client) else 1
        except Exception:
            pass
        time.sleep(.12)
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
