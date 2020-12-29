import os
import tarfile

curr_path = os.getcwd()

for path, directories, files in os.walk(f'{curr_path}/tars'):
    for f in files:
        if f.endswith(".tar.gz"):
            tar = tarfile.open(os.path.join(path,f), 'r:gz')
            tar.extractall(path=f"{curr_path}/xml")
            tar.close()