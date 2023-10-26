import subprocess
from pathlib import Path

subprocess.run(
    [
        'cd', f'{Path(__file__).resolve().parent}', "&&",
        "poetry", "export", "-f", "requirements.txt", "--output", "requirements.txt", "--without-hashes", "&&",
        "python", "-m", "pip", "install", "-r", "requirements.txt", "-t", "jobsearch/package/"
    ],
    shell=True,
    check=True,
)