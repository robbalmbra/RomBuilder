#!/usr/bin/env python3
# Produce ota json file for specific rom file

import json
import sys
import os
import hashlib

def md5(fname):
    hash_md5 = hashlib.md5()
    with open(fname, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()

if len(sys.argv) < 3:
  print("USAGE: " + sys.argv[0] + " [ROM FILE] [ROM_NAME]")
  sys.exit(1)

rom_file=sys.argv[1]
rom_name=sys.argv[2]
sf_url="https://sourceforge.net/projects/evo9810ota/files/" + rom_name + "/" + os.path.basename(rom_file) + "/download"

if not os.path.exists(rom_file):
  print("Error - '" + rom_file + "' doesn't exist")
  sys.exit(2)

if not ".zip" in rom_file or not "aicp_" in rom_file:
  print("Error - '" + os.path.basename(rom_file) + "' isn't a valid aicp rom file")
  sys.exit(4)

# Get details from file name
file_info = os.path.basename(rom_file).split("-")

json_metadata = """{
  "response": [
    {
      "datetime": """ + str(os.path.getmtime(rom_file)).split(".")[0] + """,
      "filename": """ + "\"" + os.path.basename(rom_file) + "\"" + """,
      "id": """ + "\"" + str(md5(rom_file)) + "\"" + """,
      "romtype": """ + "\"" + file_info[2] + "\"" + """,
      "size": """ + "\"" + str(os.path.getsize(rom_file)) + "\"" + """,
      "url": """ + "\"" + str(sf_url) + "\"" + """,
      "version": """ + "\"q-" + file_info[1] + "\"" + """
    }
  ]
}"""

print(json_metadata)
