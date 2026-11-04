#!/usr/bin/env python3
"""Render original ChemClaw cloud launcher PNGs; no DSH Go mascot artwork."""
from pathlib import Path
from PIL import Image, ImageDraw

BEZIERS = [
    ((23.7, 23.5), (26.6, 23.5), (29, 21.3), (29, 18.4)),
    ((29, 18.4), (29, 15.7), (27, 13.5), (24.4, 13.2)),
    ((24.4, 13.2), (23.8, 9.4), (20.5, 6.5), (16.5, 6.5)),
    ((16.5, 6.5), (13.3, 6.5), (10.5, 8.4), (9.2, 11.1)),
    ((9.2, 11.1), (6.6, 11.4), (4, 14), (4, 17.2)),
    ((4, 17.2), (4, 20.7), (6.7, 23.5), (8.5, 23.5)),
]
COLORS = {'ic_launcher': '#FAF9F5', 'ic_launcher_night': '#1F1E1B',
          'ic_launcher_frost': '#F6F3EB', 'ic_launcher_ink': '#34322D'}
ORANGE = '#F16A45'


def cubic(a, b, c, d, t):
    q = 1 - t
    return (q**3*a[0] + 3*q*q*t*b[0] + 3*q*t*t*c[0] + t**3*d[0],
            q**3*a[1] + 3*q*q*t*b[1] + 3*q*t*t*c[1] + t**3*d[1])


def render(size, background, foreground=False, round_icon=False):
    scale = 4
    image = Image.new('RGBA', (size*scale, size*scale), (0,0,0,0))
    draw = ImageDraw.Draw(image)
    if not foreground:
        boundary = (0, 0, size*scale-1, size*scale-1)
        if round_icon:
            draw.ellipse(boundary, fill=background)
        else:
            draw.rounded_rectangle(boundary, radius=int(size*scale*.21), fill=background)
    ratio = size/108*72/34 if foreground else .84*size/34
    offset = size*18/108 if foreground else size*.08
    def p(x): return ((offset+x[0]*ratio)*scale, (offset+x[1]*ratio)*scale)
    points = [p((8.5,23.5)),p((23.7,23.5))]
    for curve in BEZIERS:
        points.extend(p(cubic(*curve, t/100)) for t in range(1,101))
    thickness=max(1,round(2.3*ratio*scale))
    draw.line(points, fill=ORANGE, width=thickness, joint='curve')
    radius=1.15*ratio*scale
    for x,y in (points[0],points[-1]):
        draw.ellipse((x-radius,y-radius,x+radius,y+radius),fill=ORANGE)
    return image.resize((size,size),Image.Resampling.LANCZOS)


def main():
    res=Path(__file__).resolve().parents[1]/'android/app/src/main/res'
    assert res.is_dir(), 'mobile checkout missing res/'
    count=0
    for density,factor in [('mdpi',1),('hdpi',1.5),('xhdpi',2),('xxhdpi',3),('xxxhdpi',4)]:
        directory=res/f'mipmap-{density}'
        directory.mkdir(parents=True,exist_ok=True)
        for stem,bg in COLORS.items():
            for suffix,size,fg,round_icon in [
                    ('',int(48*factor),False,False),
                    ('_round',int(48*factor),False,True),
                    ('_foreground',int(108*factor),True,False)]:
                render(size,bg,fg,round_icon).save(directory/f'{stem}{suffix}.png')
                count+=1
    assert count==60
    print(f'Generated {count} ChemClaw cloud launcher PNGs.')


if __name__=='__main__':
    main()
