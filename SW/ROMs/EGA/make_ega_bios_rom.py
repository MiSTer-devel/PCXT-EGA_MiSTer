import os
import requests

if __name__ == "__main__":
    URL = "https://minuszerodegrees.net/rom/bin/ibm_6277356_ega_card_u44_27128.bin"
    raw_filename = "ibm_6277356_ega_card_u44_27128.bin"
    rom_filename = "ega_bios.rom"
    EXPECTED_SIZE = 16384  # 27128 EPROM: 16K x 8

    # minuszerodegrees.net's WAF rejects requests that don't look like a
    # real browser, returning an HTML error page instead of the ROM.
    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
            "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        ),
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.5",
        "Referer": "https://minuszerodegrees.net/rom/rom.htm",
    }
    response = requests.get(URL, headers=headers)
    response.raise_for_status()
    if len(response.content) != EXPECTED_SIZE:
        raise RuntimeError(
            f"Unexpected download size: got {len(response.content)} bytes, "
            f"expected {EXPECTED_SIZE}. The server may have returned an "
            f"error page instead of the ROM."
        )
    open(raw_filename, "wb").write(response.content)

    with open(raw_filename, "rb") as f:
        data = f.read()

    # The EGA card's ROM socket is fed inverted address lines, so the raw
    # EPROM dump is byte-reversed compared to how the CPU reads it (see
    # "Note 1" on minuszerodegrees.net's ROM page).
    with open(rom_filename, "wb") as romf:
        romf.write(data[::-1])

    try:
        os.remove(raw_filename)
    except:
        print("Error while deleting file : ", raw_filename)
