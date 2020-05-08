import json
import sys
import os
import hashlib
from datetime import datetime

def md5(fname):
    hash_md5 = hashlib.md5()
    with open(fname, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()

if len(sys.argv) < 4:
  print("USAGE: " + sys.argv[0] + " [ROM FILE] [ROM_NAME] [DATE]")
  sys.exit(1)

rom_file=sys.argv[1]
rom_name=sys.argv[2]
rom_json=rom_file.replace(".zip",".zip.json")
sf_url="https://sourceforge.net/projects/evo9810ota/files/" + rom_name + "/" + os.path.basename(rom_file) + "/download"

if not os.path.exists(rom_file):
  print("Error - '" + rom_file + "' doesn't exist")
  sys.exit(2)

if not ".zip" in rom_file:
  print("Error - '" + os.path.basename(rom_file) + "' isn't a valid aicp rom file")
  sys.exit(4)

with open(rom_json, 'r+') as f:

  data = json.load(f)
  now = datetime.now()
  date = now.strftime("%d-%m-%y")
  rom_filename = os.path.basename(rom_file)
  
  # Add metadata to json output
  data['website_url'] = "https://evolution-x.org"
  data['version'] = "Ten"
  data['news_url'] = "https://t.me/EvolutionXOfficial"
  data['forum_url'] = ""
  data['donate_url'] = ""
  data['error'] = False
  data['maintainer'] = "Robert Balmbra"
  data['maintainer_url'] = "https://forum.xda-developers.com/member.php?u=4834466"
  data['telegram_username'] = "robbalmbra"
  data['url'] = "https://sourceforge.net/projects/evo9810ota/files/" + rom_name + "/" + rom_filename + "/download"
  data['filehash'] = md5(rom_file)
  
  print(json.dumps(data))
