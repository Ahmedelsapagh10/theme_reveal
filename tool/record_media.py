#!/usr/bin/env python3
"""Capture actual foreground macOS pixels requested by media_capture_test.dart.
No accessibility APIs. Run with the MEDIA_DIR printed by the native test.
"""
import argparse,json,pathlib,subprocess,time
p=argparse.ArgumentParser()
p.add_argument('ipc');p.add_argument('--output',default='/private/tmp/theme-reveal-recordings')
p.add_argument('--delay',type=float,default=10)
a=p.parse_args();ipc=pathlib.Path(a.ipc);out=pathlib.Path(a.output);out.mkdir(parents=True,exist_ok=True)
print('Starting in',a.delay,'seconds. Keep the real app foreground.',flush=True)
time.sleep(a.delay)
(ipc/'start').write_text('start')
seen=set()
while not (ipc/'finished').exists():
 f=ipc/'request.json'
 if not f.exists(): time.sleep(.025);continue
 try: r=json.loads(f.read_text())
 except json.JSONDecodeError: time.sleep(.025);continue
 if r['id'] in seen: time.sleep(.025);continue
 seen.add(r['id'])
 w=json.loads(subprocess.check_output(['/private/tmp/theme-reveal-media-window']))['bounds']
 # Crop native title bar, retaining only the real Flutter client area.
 rect=','.join(str(round(x)) for x in [w['X'],w['Y']+32,w['Width'],w['Height']-32])
 if r['kind']=='video':
  target=out/(r['name']+'.mov')
  cmd=['/usr/sbin/screencapture','-v','-V'+str(r['seconds']),'-R'+rect,str(target)]
 else:
  target=out/(r['name']+'.png');cmd=['/usr/sbin/screencapture','-x','-R'+rect,str(target)]
 print(r['name'],cmd,flush=True)
 proc=subprocess.Popen(cmd,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
 (ipc/(str(r['id'])+'.started')).write_text('started')
 _,err=proc.communicate()
 (ipc/(str(r['id'])+'.finished')).write_text(str(proc.returncode))
 if proc.returncode: print(err.decode(),flush=True);break
 print('captured',target,target.stat().st_size,flush=True)
