import io
import json
import urllib.error
import urllib.request
import uuid
import wave

# 1. Login
req = urllib.request.Request(
    'http://localhost:8000/auth/login',
    data=json.dumps({'email': 'dakshin@pitchcoach.dev', 'password': 'PitchCoachSecure2026!'}).encode('utf-8'),
    headers={'Content-Type': 'application/json'}
)
with urllib.request.urlopen(req) as resp:
    token = json.loads(resp.read().decode('utf-8'))['access_token']
    print("1. Logged in successfully!")

# 2. Build 2-second WAV file in memory
buf = io.BytesIO()
with wave.open(buf, 'wb') as wf:
    wf.setnchannels(1)
    wf.setsampwidth(2)
    wf.setframerate(16000)
    wf.writeframes(b'\x00' * 64000)
wav_bytes = buf.getvalue()

# 3. Multipart form-data payload
boundary = '----PitchCoachBoundary' + uuid.uuid4().hex
parts = [
    f'--{boundary}\r\nContent-Disposition: form-data; name="audio_file"; filename="pitch_test.wav"\r\nContent-Type: audio/wav\r\n\r\n'.encode('utf-8'),
    wav_bytes,
    f'\r\n--{boundary}\r\nContent-Disposition: form-data; name="duration_seconds"\r\n\r\n2.0\r\n'.encode('utf-8'),
    f'--{boundary}\r\nContent-Disposition: form-data; name="mode"\r\n\r\npitch\r\n'.encode('utf-8'),
    f'--{boundary}\r\nContent-Disposition: form-data; name="topic_or_question"\r\n\r\nAI Pitch Coach Demo\r\n'.encode('utf-8'),
    f'--{boundary}--\r\n'.encode('utf-8'),
]
body = b''.join(parts)

session_req = urllib.request.Request(
    'http://localhost:8000/sessions',
    data=body,
    headers={
        'Content-Type': f'multipart/form-data; boundary={boundary}',
        'Authorization': f'Bearer {token}'
    }
)

try:
    with urllib.request.urlopen(session_req) as s_resp:
        result = json.loads(s_resp.read().decode('utf-8'))
        print("2. Session successfully posted through live backend!")
        print("   Session ID:", result.get("id"))
        print("   Topic:", result.get("topic_or_question"))
        print("   Duration:", result.get("duration_seconds"))
except urllib.error.HTTPError as e:
    print("HTTP error:", e.code, e.read().decode('utf-8'))
