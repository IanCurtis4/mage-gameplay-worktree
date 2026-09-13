"""Offline review of final raster cells; it does not modify the game assets."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'assets/art/animations'
OUT = ROOT / 'docs/art'
FONT = ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf', 19)
TITLE = ImageFont.truetype('C:/Windows/Fonts/segoeuib.ttf', 26)
ACTORS = [('swordsman', 'Espadachim'), ('mage', 'Mago'), ('warrior', 'Guerreiro'), ('archer', 'Arqueiro')]
COLS = ['Idle', 'Caminhada', 'Ataque / magia', 'Dano', 'Morte']
atlases = {key: Image.open(ART / f'{key}.png').convert('RGBA') for key, _ in ACTORS}
frames = []
for tick in range(48):
    back = tick >= 24
    cycle = tick % 24
    surface = Image.new('RGBA', (1160, 824), '#152c31')
    draw = ImageDraw.Draw(surface)
    draw.text((24, 14), 'RagRPG · Animações 01 · ' + ('costas' if back else 'frente'), font=TITLE, fill='#f1d19a')
    for col, label in enumerate(COLS):
        draw.text((170 + col * 194, 62), label, font=FONT, fill='#dbe7de')
    for row, (key, name) in enumerate(ACTORS):
        y = 95 + row * 178
        draw.text((16, y + 75), name, font=FONT, fill='#f1d19a')
        samples = [(16 if back else 0) + (cycle // 3) % 4,
                   (12 if back else 4) + cycle % 4,
                   (20 if back else 8) + cycle % 4,
                   24 + (2 if back else 0) + (cycle // 2) % 2,
                   28 + (2 if back else 0) + min(1, cycle % 12 // 2)]
        for col, sample in enumerate(samples):
            x = 164 + col * 194
            draw.rectangle((x, y, x + 183, y + 170), fill='#274047')
            region = (sample % 4 * 64, sample // 4 * 64, sample % 4 * 64 + 64, sample // 4 * 64 + 64)
            image = atlases[key].crop(region).resize((160, 160), Image.Resampling.NEAREST)
            surface.alpha_composite(image, (x + 10, y + 5))
    frames.append(surface.convert('RGB'))
OUT.mkdir(exist_ok=True)
frames[0].save(OUT / 'animation_contact_sheet.png')
frames[0].save(OUT / 'animation_preview.gif', save_all=True, append_images=frames[1:],
               duration=100, loop=0, optimize=False, disposal=2)
print(OUT / 'animation_preview.gif')
