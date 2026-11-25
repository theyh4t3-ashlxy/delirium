#!/usr/bin/env python3
"""
network.py — NetworkManager helper for VPNs, Hotspot, IP telemetry, saved profiles,
and zero-dependency QR code matrix generation.
"""
import json
import os
import re
import subprocess
import sys


def _esc(val: str) -> str:
    return (
        str(val or "")
        .replace("\\", "\\\\")
        .replace("\n", "\\n")
        .replace("=", "\\e")
        .replace(",", "\\c")
        .replace(";", "\\s")
        .replace("|", "\\p")
    )


def _run(cmd: list[str], timeout: int = 8) -> tuple[int, str, str]:
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout, check=False)
        return res.returncode, res.stdout.strip(), res.stderr.strip()
    except Exception as exc:
        return 1, "", str(exc)


# ==============================================================================
# Minimal pure-Python QR Code generator (Byte mode, Versions 1..6, ECC-L)
# Encodes Wi-Fi strings cleanly offline with zero external binaries.
# ==============================================================================
_EXP = [0] * 512
_LOG = [0] * 256
_x = 1
for _i in range(255):
    _EXP[_i] = _x
    _LOG[_x] = _i
    _x <<= 1
    if _x & 0x100:
        _x ^= 0x11D
for _i in range(255, 512):
    _EXP[_i] = _EXP[_i - 255]


def _gf_mul(a: int, b: int) -> int:
    if a == 0 or b == 0:
        return 0
    return _EXP[_LOG[a] + _LOG[b]]


def _rs_gen_poly(deg: int) -> list[int]:
    poly = [1]
    for i in range(deg):
        nxt = [0] * (len(poly) + 1)
        g = _EXP[i]
        for j, c in enumerate(poly):
            nxt[j] ^= c
            nxt[j + 1] ^= _gf_mul(c, g)
        poly = nxt
    return poly


def _rs_encode(data: list[int], ec_len: int) -> list[int]:
    gen = _rs_gen_poly(ec_len)
    buf = data + [0] * ec_len
    for i in range(len(data)):
        coef = buf[i]
        if coef != 0:
            for j in range(1, len(gen)):
                buf[i + j] ^= _gf_mul(gen[j], coef)
    return buf[len(data):]


# Version 1..6 Level L specs: (size, total_data_codewords, ec_per_block, blocks, align_coords)
_QR_SPECS = {
    1: (21, 19, 7, 1, []),
    2: (25, 34, 10, 1, [6, 18]),
    3: (29, 55, 15, 1, [6, 22]),
    4: (33, 80, 20, 1, [6, 26]),
    5: (37, 108, 26, 1, [6, 30]),
    6: (41, 136, 18, 2, [6, 34]),
}


def generate_qr_matrix(text: str) -> list[str]:
    payload = text.encode("utf-8")
    n = len(payload)
    ver = None
    for v, (_, cap, _, _, _) in _QR_SPECS.items():
        # Byte mode header = 4 bits + 8 bits = 12 bits; +4 terminator = 2 bytes overhead
        if n + 2 <= cap:
            ver = v
            break
    if ver is None:
        payload = payload[: _QR_SPECS[6][1] - 2]
        n = len(payload)
        ver = 6

    size, data_cap, ec_len, blocks, align = _QR_SPECS[ver]

    bits: list[int] = []
    def push_bits(val: int, width: int) -> None:
        for b in range(width - 1, -1, -1):
            bits.append((val >> b) & 1)

    push_bits(0b0100, 4)  # byte mode
    push_bits(n, 8)
    for byte in payload:
        push_bits(byte, 8)
    term = min(4, data_cap * 8 - len(bits))
    push_bits(0, term)
    while len(bits) % 8 != 0:
        bits.append(0)
    codewords = [0] * (len(bits) // 8)
    for i in range(len(codewords)):
        v = 0
        for b in range(8):
            v = (v << 1) | bits[i * 8 + b]
        codewords[i] = v
    pad_bytes = [0xEC, 0x11]
    p_idx = 0
    while len(codewords) < data_cap:
        codewords.append(pad_bytes[p_idx % 2])
        p_idx += 1

    # Split into blocks and append interleaved RS ECC
    blk_size = len(codewords) // blocks
    data_blocks = []
    ec_blocks = []
    pos = 0
    for _ in range(blocks):
        db = codewords[pos : pos + blk_size]
        pos += blk_size
        data_blocks.append(db)
        ec_blocks.append(_rs_encode(db, ec_len))

    stream: list[int] = []
    for i in range(blk_size):
        for db in data_blocks:
            stream.append(db[i])
    for i in range(ec_len):
        for eb in ec_blocks:
            stream.append(eb[i])

    # Build grid + reserve function modules
    mat = [[-1] * size for _ in range(size)]
    func = [[False] * size for _ in range(size)]

    def set_fn(r: int, c: int, val: int) -> None:
        if 0 <= r < size and 0 <= c < size:
            mat[r][c] = val
            func[r][c] = True

    def place_finder(r0: int, c0: int) -> None:
        for dr in range(-1, 8):
            for dc in range(-1, 8):
                r, c = r0 + dr, c0 + dc
                if not (0 <= r < size and 0 <= c < size):
                    continue
                if dr in (-1, 7) or dc in (-1, 7):
                    set_fn(r, c, 0)
                elif dr in (0, 6) or dc in (0, 6) or (2 <= dr <= 4 and 2 <= dc <= 4):
                    set_fn(r, c, 1)
                else:
                    set_fn(r, c, 0)

    place_finder(0, 0)
    place_finder(0, size - 7)
    place_finder(size - 7, 0)

    # Alignment patterns
    for ar in align:
        for ac in align:
            if func[ar][ac]:
                continue
            for dr in range(-2, 3):
                for dc in range(-2, 3):
                    val = 1 if (abs(dr) == 2 or abs(dc) == 2 or (dr == 0 and dc == 0)) else 0
                    set_fn(ar + dr, ac + dc, val)

    # Timing patterns
    for i in range(8, size - 8):
        val = 1 if i % 2 == 0 else 0
        if not func[6][i]:
            set_fn(6, i, val)
        if not func[i][6]:
            set_fn(i, 6, val)

    # Reserve format info & dark module
    for i in range(9):
        if i != 6:
            set_fn(8, i, 0)
            set_fn(i, 8, 0)
    for i in range(size - 8, size):
        set_fn(8, i, 0)
        set_fn(i, 8, 0)
    set_fn(size - 8, 8, 1)

    # Place data bits zigzag
    bit_stream = []
    for cw in stream:
        for b in range(7, -1, -1):
            bit_stream.append((cw >> b) & 1)

    idx = 0
    up = True
    col = size - 1
    while col > 0:
        if col == 6:
            col -= 1
        rows = range(size - 1, -1, -1) if up else range(size)
        for r in rows:
            for dc in (0, -1):
                c = col + dc
                if not func[r][c]:
                    mat[r][c] = bit_stream[idx] if idx < len(bit_stream) else 0
                    idx += 1
        col -= 2
        up = not up

    # Try masks 0..7 and pick lowest penalty
    def mask_fn(m: int, r: int, c: int) -> bool:
        if m == 0: return (r + c) % 2 == 0
        if m == 1: return r % 2 == 0
        if m == 2: return c % 3 == 0
        if m == 3: return (r + c) % 3 == 0
        if m == 4: return ((r // 2) + (c // 3)) % 2 == 0
        if m == 5: return ((r * c) % 2) + ((r * c) % 3) == 0
        if m == 6: return (((r * c) % 2) + ((r * c) % 3)) % 2 == 0
        return (((r + c) % 2) + ((r * c) % 3)) % 2 == 0

    def apply_format(grid: list[list[int]], mask: int) -> None:
        # Format bits for ECC-L (01) + 3-bit mask, BCH(15,5) ^ 0x5412
        fmt = (0b01 << 3) | mask
        rem = fmt << 10
        gen = 0b10100110111
        for b in range(14, 9, -1):
            if (rem >> b) & 1:
                rem ^= gen << (b - 10)
        code = ((fmt << 10) | rem) ^ 0x5412
        coords1 = [(8, 0), (8, 1), (8, 2), (8, 3), (8, 4), (8, 5), (8, 7), (8, 8),
                   (7, 8), (5, 8), (4, 8), (3, 8), (2, 8), (1, 8), (0, 8)]
        for i in range(15):
            bit = (code >> (14 - i)) & 1
            r1, c1 = coords1[i]
            grid[r1][c1] = bit
            if i < 8:
                grid[size - 1 - i if i < 7 else 8][8 if i < 7 else size - 8] = bit
                if i < 7:
                    grid[size - 1 - i][8] = bit
                else:
                    grid[8][size - 8] = bit
            else:
                grid[8][size - 15 + i] = bit

    best_grid = None
    best_pen = 10**9
    for m in range(8):
        g = [row[:] for row in mat]
        for r in range(size):
            for c in range(size):
                if not func[r][c] and mask_fn(m, r, c):
                    g[r][c] ^= 1
        apply_format(g, m)

        pen = 0
        for r in range(size):
            run = 1
            for c in range(1, size):
                if g[r][c] == g[r][c - 1]:
                    run += 1
                    if run == 5: pen += 3
                    elif run > 5: pen += 1
                else:
                    run = 1
        for c in range(size):
            run = 1
            for r in range(1, size):
                if g[r][c] == g[r - 1][c]:
                    run += 1
                    if run == 5: pen += 3
                    elif run > 5: pen += 1
                else:
                    run = 1
        dark = sum(sum(r) for r in g)
        pct = abs((dark * 100) // (size * size) - 50) // 5
        pen += pct * 10
        if pen < best_pen:
            best_pen = pen
            best_grid = g

    return ["".join("1" if cell else "0" for cell in row) for row in best_grid]


def _wifi_qr_payload(ssid: str, password: str, sec: str = "WPA") -> str:
    def qesc(s: str) -> str:
        return s.replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,").replace(":", "\\:")
    if not password:
        return f"WIFI:T:nopass;S:{qesc(ssid)};;"
    return f"WIFI:T:{sec};S:{qesc(ssid)};P:{qesc(password)};;"


def _read_net_stats(iface: str) -> tuple[int, int]:
    if not iface:
        return 0, 0
    base = f"/sys/class/net/{iface}/statistics"
    try:
        rx = int(open(f"{base}/rx_bytes").read().strip())
        tx = int(open(f"{base}/tx_bytes").read().strip())
        return rx, tx
    except Exception:
        return 0, 0


def cmd_status() -> None:
    rc, devs_raw, _ = _run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "dev", "status"])
    active_iface = ""
    active_con = ""
    active_type = ""
    wifi_iface = ""

    for line in devs_raw.splitlines():
        parts = line.split(":")
        if len(parts) < 4:
            continue
        dev, typ, state, con = parts[0], parts[1], parts[2], ":".join(parts[3:])
        if typ == "wifi" and not wifi_iface:
            wifi_iface = dev
        if state.startswith("connected") and typ in ("wifi", "ethernet"):
            if not active_iface or typ == "ethernet":
                active_iface, active_type, active_con = dev, typ, con

    ip4 = ""
    gw = ""
    dns = ""
    if active_iface:
        _, show_out, _ = _run(["nmcli", "-t", "-f", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS", "dev", "show", active_iface])
        dns_list = []
        for l in show_out.splitlines():
            if l.startswith("IP4.ADDRESS"):
                ip4 = l.split(":", 1)[1].strip()
            elif l.startswith("IP4.GATEWAY"):
                gw = l.split(":", 1)[1].strip()
            elif l.startswith("IP4.DNS"):
                val = l.split(":", 1)[1].strip()
                if val:
                    dns_list.append(val)
        dns = ", ".join(dns_list[:2])

    rx_b, tx_b = _read_net_stats(active_iface or wifi_iface)

    # Connections: VPNs, hotspot, and saved Wi-Fi profiles
    _, cons_raw, _ = _run(["nmcli", "-t", "-f", "NAME,UUID,TYPE,DEVICE,ACTIVE", "con", "show"])
    vpns = []
    saved_wifi = []
    hotspot_active = False
    hotspot_name = ""

    for line in cons_raw.splitlines():
        # Split carefully (nmcli escapes \: inside names)
        cols = re.split(r"(?<!\\):", line)
        if len(cols) < 5:
            continue
        name = cols[0].replace("\\:", ":")
        uuid, ctype, dev, active = cols[1], cols[2], cols[3], cols[4]
        is_act = (active.lower() == "yes")

        if ctype in ("vpn", "wireguard", "tun") or "vpn" in ctype.lower():
            vpns.append({"name": name, "uuid": uuid, "type": ctype, "active": is_act})
        elif ctype == "802-11-wireless":
            # Check if AP/hotspot mode
            _, mode_out, _ = _run(["nmcli", "-g", "802-11-wireless.mode", "con", "show", "uuid", uuid], timeout=2)
            if mode_out.strip() == "ap" or name == "Hotspot":
                if is_act:
                    hotspot_active = True
                    hotspot_name = name
            else:
                saved_wifi.append({"name": name, "uuid": uuid, "active": is_act})

    print(f"iface={_esc(active_iface or wifi_iface)}")
    print(f"wifi_iface={_esc(wifi_iface)}")
    print(f"active_con={_esc(active_con)}")
    print(f"active_type={_esc(active_type)}")
    print(f"ip4={_esc(ip4)}")
    print(f"gateway={_esc(gw)}")
    print(f"dns={_esc(dns)}")
    print(f"rx_bytes={rx_b}")
    print(f"tx_bytes={tx_b}")
    print(f"hotspot_active={'true' if hotspot_active else 'false'}")
    print(f"hotspot_name={_esc(hotspot_name)}")
    print(f"vpn_count={len(vpns)}")
    for i, v in enumerate(vpns):
        print(f"vpn.{i}.name={_esc(v['name'])}")
        print(f"vpn.{i}.uuid={_esc(v['uuid'])}")
        print(f"vpn.{i}.type={_esc(v['type'])}")
        print(f"vpn.{i}.active={'true' if v['active'] else 'false'}")
    print(f"saved_count={len(saved_wifi)}")
    for i, s in enumerate(saved_wifi):
        print(f"saved.{i}.name={_esc(s['name'])}")
        print(f"saved.{i}.uuid={_esc(s['uuid'])}")
        print(f"saved.{i}.active={'true' if s['active'] else 'false'}")


def cmd_qr(ssid: str = "", password: str = "") -> None:
    target_ssid = ssid
    target_pass = password
    if not target_ssid:
        # Grab active wifi credentials cleanly via nmcli
        _, out, _ = _run(["nmcli", "-s", "-t", "-f", "NAME,TYPE,ACTIVE", "con", "show", "--active"])
        for l in out.splitlines():
            cols = re.split(r"(?<!\\):", l)
            if len(cols) >= 3 and cols[1] == "802-11-wireless" and cols[2] == "yes":
                con_name = cols[0].replace("\\:", ":")
                _, s_out, _ = _run(["nmcli", "-g", "802-11-wireless.ssid", "con", "show", con_name])
                _, p_out, _ = _run(["nmcli", "-s", "-g", "802-11-wireless-security.psk", "con", "show", con_name])
                target_ssid = s_out.strip() or con_name
                target_pass = p_out.strip()
                break
    elif target_ssid and not target_pass:
        _, p_out, _ = _run(["nmcli", "-s", "-g", "802-11-wireless-security.psk", "con", "show", target_ssid])
        target_pass = p_out.strip()

    if not target_ssid:
        print("ok=false\nerror=no active wi-fi ssid found")
        return

    payload = _wifi_qr_payload(target_ssid, target_pass)
    rows = generate_qr_matrix(payload)
    print("ok=true")
    print(f"ssid={_esc(target_ssid)}")
    print(f"password={_esc(target_pass)}")
    print(f"size={len(rows)}")
    print(f"rows={'|'.join(rows)}")


def cmd_hotspot(action: str, ssid: str = "quickshell-ap", password: str = "nixoshotspot") -> None:
    _, devs_raw, _ = _run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "dev", "status"])
    wifi_dev = ""
    active_ap = ""
    for l in devs_raw.splitlines():
        parts = l.split(":")
        if len(parts) >= 4 and parts[1] == "wifi":
            wifi_dev = parts[0]
            con = ":".join(parts[3:])
            if parts[2].startswith("connected") and con:
                _, mode_out, _ = _run(["nmcli", "-g", "802-11-wireless.mode", "con", "show", con])
                if mode_out.strip() == "ap" or con == "Hotspot":
                    active_ap = con

    if action == "off" or (action == "toggle" and active_ap):
        rc, _, err = _run(["nmcli", "con", "down", active_ap or "Hotspot"])
        print(f"ok={'true' if rc == 0 else 'false'}")
        print("active=false")
        if rc != 0:
            print(f"error={_esc(err)}")
        return

    if not wifi_dev:
        print("ok=false\nerror=no wi-fi adapter found")
        return

    s = ssid.strip() or "quickshell-ap"
    p = password.strip() or "nixoshotspot"
    if len(p) < 8:
        print("ok=false\nerror=hotspot password must be at least 8 characters")
        return

    rc, out, err = _run(
        ["nmcli", "dev", "wifi", "hotspot", "ifname", wifi_dev, "ssid", s, "password", p],
        timeout=15,
    )
    print(f"ok={'true' if rc == 0 else 'false'}")
    print(f"active={'true' if rc == 0 else 'false'}")
    print(f"ssid={_esc(s)}")
    print(f"password={_esc(p)}")
    if rc != 0:
        print(f"error={_esc(err or out)}")


def cmd_vpn(action: str, name: str) -> None:
    sub = "up" if action == "up" else "down"
    rc, out, err = _run(["nmcli", "con", sub, "id", name], timeout=15)
    print(f"ok={'true' if rc == 0 else 'false'}")
    if rc != 0:
        print(f"error={_esc(err or out)}")


def cmd_forget(target: str) -> None:
    rc, out, err = _run(["nmcli", "con", "delete", target], timeout=8)
    print(f"ok={'true' if rc == 0 else 'false'}")
    if rc != 0:
        print(f"error={_esc(err or out)}")


def main() -> None:
    args = sys.argv[1:]
    if not args or args[0] == "status":
        cmd_status()
        return
    cmd = args[0].lower()
    if cmd == "qr":
        cmd_qr(args[1] if len(args) > 1 else "", args[2] if len(args) > 2 else "")
    elif cmd == "hotspot":
        act = args[1].lower() if len(args) > 1 else "toggle"
        ssid = args[2] if len(args) > 2 else "quickshell-ap"
        pwd = args[3] if len(args) > 3 else "nixoshotspot"
        cmd_hotspot(act, ssid, pwd)
    elif cmd == "vpn" and len(args) >= 3:
        cmd_vpn(args[1].lower(), args[2])
    elif cmd == "forget" and len(args) >= 2:
        cmd_forget(args[1])
    else:
        cmd_status()


if __name__ == "__main__":
    main()
