"""Fetch only Android files from Godot's .tpz release (zip) using HTTP ranges."""
import os, struct, sys, urllib.request, urllib.parse, zipfile, io

SRC = "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
DEST = os.path.join(os.environ["APPDATA"], "Godot", "export_templates", "4.7.2.stable")
WANT = ("android_debug.apk", "android_release.apk", "android_source.zip", "version.txt")


def get_final_url(url):
    req = urllib.request.Request(url, method="HEAD")
    with urllib.request.urlopen(req) as r:
        return r.geturl()


def fetch_range(url, start, end):
    req = urllib.request.Request(url, headers={"Range": f"bytes={start}-{end}"})
    with urllib.request.urlopen(req) as r:
        return r.read()


def main():
    url = get_final_url(SRC)
    req = urllib.request.Request(url, method="HEAD")
    with urllib.request.urlopen(req) as r:
        total = int(r.headers["Content-Length"])
    tail = fetch_range(url, max(0, total - 131072), total - 1)
    i = tail.rfind(b"PK\x05\x06")
    if i < 0:
        raise SystemExit("no zip EOCD")
    cd_size, cd_off = struct.unpack("<II", tail[i + 12:i + 20])
    cd = fetch_range(url, cd_off, cd_off + cd_size - 1)
    zf = zipfile.ZipFile(io.BytesIO(cd + tail[i:]))
    names = [n for n in zf.namelist() if n.rsplit("/", 1)[-1] in WANT]
    if not names:
        raise SystemExit("no android entries; first entries: %r" % zf.namelist()[:5])
    os.makedirs(DEST, exist_ok=True)
    for n in names:
        info = zf.getinfo(n)
        out = os.path.join(DEST, os.path.basename(n))
        print(f"fetching {n} ({info.file_size/1048576:.1f} MB)", flush=True)
        # Local header size is needed to find the data offset; fetch it.
        lh = fetch_range(url, info.header_offset, info.header_offset + 4095)
        if lh[:4] != b"PK\x03\x04":
            raise SystemExit("bad local header for " + n)
        fname_len, extra_len = struct.unpack("<HH", lh[26:30])
        start = info.header_offset + 30 + fname_len + extra_len
        data = fetch_range(url, start, start + info.compress_size - 1) if info.compress_type == zipfile.ZIP_STORED else None
        if data is None:
            # compressed entry: fall back to a fresh range on the whole compressed body
            data = fetch_range(url, start, start + info.compress_size - 1)
            data = zipfile._get_decompressor(info.compress_type).decompress(data) if False else data
        with open(out, "wb") as f:
            if info.compress_type == zipfile.ZIP_STORED:
                f.write(data)
            else:
                # build a minimal local-file zip for decompression
                payload = lh[:30] + lh[30:30 + fname_len + extra_len] + data
                with zipfile.ZipFile(io.BytesIO(payload + b"PK\x01\x02" + b"\x00" * 42)) as _:
                    pass
                raise SystemExit("compressed entry not supported: " + n)
        print(f"saved {out}", flush=True)


if __name__ == "__main__":
    main()
