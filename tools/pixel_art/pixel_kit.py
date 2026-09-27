"""Kit mínimo para dibujar pixel art a mano: rejilla, paleta común, contorno automático y exportación.

Cada sprite se dibuja colocando tiras de píxeles con put(y, x, "cadena"): cada carácter es un
color de la paleta y '.' deja el píxel como está. Después outline() añade el contorno exterior
de 1 px y save() exporta el PNG con transparencia (a escala 1 y ampliado sin suavizado).
"""
from PIL import Image

PALETTE = {
    'O': '#241826',  # contorno
    'K': '#120c14',  # casi negro (ojos, pupilas)
    'Y': '#ffffff',  # blanco (brillos)
    # piel
    's': '#f7d2ae', 'S': '#e0a47c', 'q': '#b3735a',
    # pelo castaño / cuero oscuro
    'h': '#c07a42', 'H': '#8f4f2c', 'k': '#5c2e1f',
    # rojo
    'r': '#f0604e', 'R': '#c23644', 'x': '#7e2036',
    # cuero
    'l': '#c8905a', 'L': '#9c6238', 'd': '#6b3b24',
    # azul
    'b': '#6a9ee8', 'B': '#4468b8', 'n': '#2c3f7a',
    # acero
    'm': '#eef2f6', 'M': '#b3bdca', 'i': '#77829a', 'I': '#4b5367',
    # oro
    'g': '#ffe07a', 'G': '#e6a832', 'j': '#a8661a',
    # madera
    'w': '#d49a5e', 'W': '#a06b3c', 'v': '#6b4226',
    # verde
    'a': '#b4ee80', 'A': '#6cc252', 'c': '#3a8a45', 'C': '#22553a',
    # hueso
    'e': '#f8f0da', 'E': '#dccda8', 'u': '#ab9774',
    # morado
    'p': '#c496f0', 'P': '#8a5ccc', 'z': '#5a3596', 'Z': '#351f5e',
    # piedra
    't': '#c4bfb6', 'T': '#958f86', 'o': '#68635d', 'U': '#45413d',
    # hielo / espectral
    'f': '#e0fdff', 'F': '#9ae8f2', 'y': '#56b8d0', 'Q': '#2e7596',
    # fuego / lava
    '1': '#fff3a8', '2': '#ffba45', '3': '#f5722c', '4': '#c2381c',
    # extras
    '5': '#ff5040',  # rojo brillante (ojos malvados)
    '6': '#f28c9a',  # rosa (mejillas, lengua)
    '7': '#ffd0e8',  # rosa claro (brillos mágicos)
    '8': '#fef6e4',  # crema (camisa, delantal claro)
    '9': '#3a2a30',  # sombra muy oscura interior
    # basalto cálido (Señor del Magma)
    'D': '#8a6150', 'N': '#5a3a33', 'V': '#3a2422',
}


def hex_to_rgba(h):
    h = h.lstrip('#')
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


class Sprite:
    def __init__(self, w, h):
        self.w = w
        self.h = h
        self.px = [['.'] * w for _ in range(h)]

    def put(self, y, x, s):
        for i, ch in enumerate(s):
            if ch == '.':
                continue
            xx = x + i
            if 0 <= xx < self.w and 0 <= y < self.h:
                if ch not in PALETTE and ch != ' ':
                    raise ValueError(f"color desconocido {ch!r} en ({xx},{y})")
                if ch == ' ':
                    continue
                self.px[y][xx] = ch
        return self

    def rows(self, y0, x0, lines):
        """Coloca varias filas seguidas empezando en (x0, y0)."""
        for k, line in enumerate(lines):
            self.put(y0 + k, x0, line)
        return self

    def rect(self, x, y, w, h, ch):
        for yy in range(y, y + h):
            self.put(yy, x, ch * w)
        return self

    def line(self, pts, ch):
        """Polilínea de 1 px (Bresenham) por los puntos dados."""
        for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
            dx, dy = abs(x1 - x0), abs(y1 - y0)
            sx, sy = (1 if x1 > x0 else -1), (1 if y1 > y0 else -1)
            err = dx - dy
            x, y = x0, y0
            while True:
                self.put(y, x, ch)
                if (x, y) == (x1, y1):
                    break
                e2 = 2 * err
                if e2 > -dy:
                    err -= dy
                    x += sx
                if e2 < dx:
                    err += dx
                    y += sy
        return self

    def erase(self, y, x, n=1):
        for i in range(n):
            if 0 <= x + i < self.w and 0 <= y < self.h:
                self.px[y][x + i] = '.'
        return self

    def fill_poly(self, pts, ch):
        """Rellena un polígono (vértices en píxeles) comprobando el centro de cada píxel.
        ch puede ser un carácter o una función (x, y) -> carácter."""
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        for y in range(max(0, int(min(ys))), min(self.h, int(max(ys)) + 1)):
            for x in range(max(0, int(min(xs))), min(self.w, int(max(xs)) + 1)):
                px, py = x + 0.5, y + 0.5
                inside = False
                j = len(pts) - 1
                for i in range(len(pts)):
                    xi, yi = pts[i]
                    xj, yj = pts[j]
                    if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi) + xi:
                        inside = not inside
                    j = i
                if inside:
                    c = ch(x, y) if callable(ch) else ch
                    if c and c != '.':
                        self.px[y][x] = c
        return self

    def fill_ellipse(self, cx, cy, rx, ry, ch):
        """Rellena una elipse; ch puede ser función (x, y, nx, ny) con coordenadas normalizadas."""
        for y in range(self.h):
            for x in range(self.w):
                nx = (x + 0.5 - cx) / rx
                ny = (y + 0.5 - cy) / ry
                if nx * nx + ny * ny <= 1.0:
                    c = ch(x, y, nx, ny) if callable(ch) else ch
                    if c and c != '.':
                        self.px[y][x] = c
        return self

    def outline(self, ch='O', diagonals=False):
        """Contorno exterior de 1 px alrededor de la silueta."""
        src = [row[:] for row in self.px]
        for y in range(self.h):
            for x in range(self.w):
                if src[y][x] != '.':
                    continue
                neigh = [(0, -1), (0, 1), (-1, 0), (1, 0)]
                if diagonals:
                    neigh += [(-1, -1), (1, -1), (-1, 1), (1, 1)]
                for dx, dy in neigh:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < self.w and 0 <= ny < self.h and src[ny][nx] not in ('.', ch):
                        self.px[y][x] = ch
                        break
        return self

    def stamp(self, other, edge=None):
        """Pega otro sprite encima. Con edge, el borde de 'other' que toca algo ya pintado se oscurece:
        es el contorno interior que separa un brazo del torso que tiene detrás."""
        base = [row[:] for row in self.px]
        for y in range(self.h):
            for x in range(self.w):
                ch = other.px[y][x]
                if ch == '.':
                    continue
                self.px[y][x] = ch
                if edge:
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if (0 <= nx < self.w and 0 <= ny < self.h
                                and other.px[ny][nx] == '.' and base[ny][nx] != '.'):
                            self.px[y][x] = edge
                            break
        return self

    def copy(self):
        s = Sprite(self.w, self.h)
        s.px = [row[:] for row in self.px]
        return s

    def flip(self):
        """Espejo horizontal (los enemigos se dibujan mirando a la derecha y se voltean)."""
        out = self.copy()
        out.px = [row[::-1] for row in self.px]
        return out

    def shift_rows(self, y_from, y_to, dy):
        """Desplaza verticalmente las filas [y_from, y_to] dy píxeles (para fotogramas de respiración)."""
        out = self.copy()
        band = [self.px[y][:] for y in range(y_from, y_to + 1)]
        for y in range(y_from, y_to + 1):
            out.px[y] = ['.'] * self.w
        for k, row in enumerate(band):
            ny = y_from + k + dy
            if 0 <= ny < self.h:
                for x, ch in enumerate(row):
                    if ch != '.':
                        out.px[ny][x] = ch
        return out

    def image(self):
        img = Image.new('RGBA', (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                ch = self.px[y][x]
                if ch != '.':
                    img.putpixel((x, y), hex_to_rgba(PALETTE[ch]))
        return img

    def save(self, path, scale=1):
        img = self.image()
        if scale != 1:
            img = img.resize((self.w * scale, self.h * scale), Image.NEAREST)
        img.save(path)
        return img


def preview(sprites, path, scale=8, bg=(52, 38, 44), pad=2):
    """Hoja de revisión: sprites lado a lado sobre un fondo liso."""
    ims = [s.image() for s in sprites]
    w = sum(i.width for i in ims) + pad * (len(ims) + 1)
    h = max(i.height for i in ims) + pad * 2
    sheet = Image.new('RGBA', (w, h), bg + (255,))
    x = pad
    for i in ims:
        sheet.alpha_composite(i, (x, h - pad - i.height))
        x += i.width + pad
    sheet = sheet.resize((w * scale, h * scale), Image.NEAREST)
    sheet.save(path)
    return sheet
