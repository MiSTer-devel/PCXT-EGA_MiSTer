import os
import requests

if __name__ == "__main__":
    URL = "https://minuszerodegrees.net/rom/bin/ibm_6277356_ega_card_u44_27128.bin"
    raw_filename = "ibm_6277356_ega_card_u44_27128.bin"
    rom_filename = "ega_bios.rom"

    response = requests.get(URL)
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
