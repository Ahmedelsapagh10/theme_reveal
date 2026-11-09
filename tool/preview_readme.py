#!/usr/bin/env python3
"""Render a local GFM-style preview; production README has no custom CSS."""
import pathlib,re,sys
from markdown_it import MarkdownIt
root=pathlib.Path(__file__).resolve().parents[1]
s=(root/'README.md').read_text()
s=s.replace('https://raw.githubusercontent.com/Ahmedelsapagh10/theme_reveal/master/','/')
md=MarkdownIt('commonmark',{'html':True}).enable('table').enable('strikethrough')
section = '--gallery' in sys.argv
if section:
 s = s[s.index('## Visual gallery'):s.index('## Cookbook')]
 s += '\n## Compiled code preview\n\n' + (root/'README.md').read_text().split('```dart\n')[1].split('\n```')[0].join(['```dart\n','\n```'])
body=md.render(s)
def heading(m):
 level,text=m.group(1),m.group(2)
 slug=re.sub(r'[^a-z0-9 -]','',re.sub('<[^>]+>','',text).lower()).replace(' ','-')
 return f'<h{level} id="{slug}">{text}</h{level}>'
body=re.sub(r'<h([1-6])>(.*?)</h\1>',heading,body)
css='body{max-width:980px;margin:40px auto;padding:0 24px;color:#20252d;font:16px/1.6 system-ui;background:white}img{max-width:100%;height:auto}table{border-collapse:collapse;width:100%;margin:20px 0}td,th{padding:10px;border:1px solid #d6dce4;text-align:left;vertical-align:top}th{background:#f5f7fa}pre{background:#f5f7fa;padding:16px;overflow:auto;border-radius:8px}code{font:13px/1.5 monospace}a{color:#315fc7}h2{border-bottom:1px solid #ddd;padding-bottom:8px;margin-top:40px}details{background:#f5f7fa;padding:12px;border-radius:8px}'
(root/('doc/media/preview_gallery.html' if section else 'doc/media/preview.html')).write_text('<!doctype html><html><head><meta charset="utf-8"><title>Theme Reveal Kit README preview</title><style>'+css+'</style></head><body>'+body+'</body></html>')
print('Rendered tables:',body.count('<table>'),'images:',body.count('<img'),'code blocks:',body.count('<pre>'))
