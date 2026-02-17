
# Minimal worker placeholder for processing uploads (transcode, etc.)
# In real app use Celery / RQ and ffmpeg worker nodes

import time

def process_upload(key):
    print("processing", key)
    time.sleep(2)
    print("done")
