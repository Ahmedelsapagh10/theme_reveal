#!/usr/bin/env python3
"""Check README anchors, local repository targets and optional remote HTTP status."""
import concurrent.futures,json,pathlib,re,subprocess,sys
root=pathlib.Path(__file__).resolve().parents[1];text=(root/'README.md').read_text()
repo='https://github.com/Ahmedelsapagh10/theme_reveal';raw='https://raw.githubusercontent.com/Ahmedelsapagh10/theme_reveal/master/'
urls=set(re.findall(r'\]\(([^)]+)\)',text)+re.findall(r'<(?:img|a)[^>]+(?:src|href)="([^"]+)"',text))
urls.update(re.findall(r'^https?://\S+|(?<=: )https?://\S+', (root/'pubspec.yaml').read_text(), re.M))
anchors=set(re.sub(r'[^a-z0-9 -]','',x.lower()).replace(' ','-') for x in re.findall(r'^#{1,6} (.+)$',text,re.M))
results=[]
for url in sorted(urls):
 row={'url':url}
 if url.startswith('#'):row['exists']=url[1:] in anchors
 elif url.startswith(raw):row['local_exists']=(root/url[len(raw):]).is_file()
 elif url.startswith(repo+'/blob/master/'):row['local_exists']=(root/url[len(repo+'/blob/master/'):]).is_file()
 elif url.startswith(repo+'/tree/master/'):row['local_exists']=(root/url[len(repo+'/tree/master/'):]).is_dir()
 results.append(row)
if '--remote' in sys.argv:
 def check(row):
  if row['url'].startswith('http'):
   p=subprocess.run(['curl','-I','-L','-s','-o','/dev/null','-w','%{http_code}','--max-time','25',row['url']],capture_output=True,text=True)
   row['http']=p.stdout or 'network-error'
  return row
 with concurrent.futures.ThreadPoolExecutor(max_workers=4) as executor:results=list(executor.map(check,results))
out=pathlib.Path('/private/tmp/theme-reveal-readme-links.json');out.write_text(json.dumps(results,indent=2)+'\n')
print('Targets:',len(results),'broken local/anchors:',sum(r.get('exists') is False or r.get('local_exists') is False for r in results))
for row in results:
 if 'http' in row and not str(row['http']).startswith('2'):print(row['http'],row['url'])
print('Detailed report:',out)
