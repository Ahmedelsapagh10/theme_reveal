#!/usr/bin/env python3
"""Convert real screencapture MOV files to bounded, palette-optimized GIFs."""
import argparse,json,pathlib,subprocess
p=argparse.ArgumentParser();p.add_argument('--ffmpeg',required=True)
p.add_argument('--persistence-input');p.add_argument('--input',default='/private/tmp/theme-reveal-recordings');p.add_argument('--output',default='doc/media')
a=p.parse_args();src=pathlib.Path(a.input);out=pathlib.Path(a.output);out.mkdir(parents=True,exist_ok=True)
manifest=[]
for name in ['hero','shapes','logo_svg','logo_png','strategies','playground']:
 source=src/(name+'.mov')
 if not source.exists():continue
 target=out/(name+'.gif')
 for width,colors in [(800,96),(800,64),(720,64),(640,48)]:
  filt=f'fps=15,scale={width}:-1:flags=lanczos,split[x][y];[x]palettegen=max_colors={colors}:stats_mode=diff[p];[y][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle'
  subprocess.run([a.ffmpeg,'-hide_banner','-loglevel','error','-i',str(source),'-filter_complex',filt,'-loop','0','-y',str(target)],check=True)
  if target.stat().st_size<=1500000:break
 if target.stat().st_size>1500000:raise RuntimeError(f'{name} exceeds limit')
 manifest.append({'file':target.name,'bytes':target.stat().st_size,'width':width,'fps':15,'palette':colors})
 print(manifest[-1],flush=True)
for name in ['settings_tab','home_light','home_dark']:
 source=src/(name+'.png');target=out/(name+'.png')
 if source.exists():
  subprocess.run(['magick',str(source),'-resize','800x','-strip',str(target)],check=True)
  manifest.append({'file':target.name,'bytes':target.stat().st_size})
persist=pathlib.Path(a.persistence_input) if a.persistence_input else src
before,after=persist/'persistence_before.mov',persist/'persistence_after.mov'
if before.exists() and after.exists():
 font='/System/Library/Fonts/Helvetica.ttc'
 filt=(f"[0:v]fps=15,scale=800:600,drawtext=fontfile={font}:text='Theme saved - first process':fontsize=22:fontcolor=white:box=1:boxcolor=black@0.75:x=20:y=h-40[a];"
       f"[1:v]fps=15,scale=800:600,drawtext=fontfile={font}:text='After full quit - new process':fontsize=22:fontcolor=white:box=1:boxcolor=black@0.75:x=20:y=h-40[b];"
       "[a][b]concat=n=2:v=1:a=0,split[x][y];[x]palettegen=max_colors=96:stats_mode=diff[p];[y][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle")
 target=out/'persistence.gif'
 subprocess.run([a.ffmpeg,'-hide_banner','-loglevel','error','-i',str(before),'-i',str(after),'-filter_complex',filt,'-loop','0','-y',str(target)],check=True)
 manifest.append({'file':target.name,'bytes':target.stat().st_size,'width':800,'fps':15,'palette':96,'edit':'Labeled cut between two actual OS processes'})
 if target.stat().st_size>1500000:raise RuntimeError('persistence exceeds limit')
(out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
