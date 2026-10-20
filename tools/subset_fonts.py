"""Subset the three OFL fonts to the glyphs actually used by the project."""
import subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAME = ROOT / "game"
FONTS = GAME / "assets" / "fonts"
SOURCES = {
    "SourceHanSerifCN-Regular.otf": "SourceHanSerifCN-Regular.subset.otf",
    "SourceHanSerifCN-Bold.otf": "SourceHanSerifCN-Bold.subset.otf",
    "SourceHanSansCN-Regular.otf": "SourceHanSansCN-Regular.subset.otf",
}


def collect_text() -> str:
    chunks = []
    for pattern in ("scripts/**/*.gd", "scenes/**/*.tscn", "data/**/*.tres", "localization/*.csv"):
        for path in GAME.glob(pattern):
            chunks.append(path.read_text(encoding="utf-8"))
    extra = "".join(chr(c) for c in range(0x20, 0x7F))
    extra += "·—–…‘’“”「」『』〈〉《》【】、。，：；！？（）［］｛｝≤≥≈×÷°±→←↑↓✓✕›«»§¶†‡•"
    return "".join(sorted(set("".join(chunks) + extra)))


def main():
    text = collect_text()
    glyph_file = FONTS / "glyphs.txt"
    glyph_file.write_text(text, encoding="utf-8")
    print(f"glyphs: {len(text)}")
    for src, dst in SOURCES.items():
        src_path = FONTS / src
        if not src_path.exists():
            print(f"skip missing {src}")
            continue
        subprocess.run([
            sys.executable, "-m", "fontTools.subset", str(src_path),
            f"--text-file={glyph_file}", f"--output-file={FONTS / dst}",
            "--layout-features=*", "--glyph-names", "--symbol-cmap", "--legacy-cmap",
            "--notdef-glyph", "--notdef-outline", "--recommended-glyphs",
            "--name-IDs=*", "--name-legacy", "--name-languages=*",
        ], check=True)
        print(f"{dst}: {src_path.stat().st_size/1024:.0f} KB -> {(FONTS / dst).stat().st_size/1024:.0f} KB")


if __name__ == "__main__":
    main()
